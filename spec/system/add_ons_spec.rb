require 'rails_helper'

RSpec.describe "Add Ons", type: :system do
  attr_reader :user, :account, :cluster

  before do
    result = sign_in_user
    @user = result[:user]
    @account = result[:account]
    @cluster = create(:cluster, account: account, name: "test-cluster")

    k8_client = double("K8::Client")
    allow(K8::Client).to receive(:new).and_return(k8_client)
    allow(k8_client).to receive(:version).and_return({ 'serverVersion' => { 'gitVersion' => 'v1.28.0' } })
    allow(k8_client).to receive(:can_connect?).and_return(true)
    allow(k8_client).to receive(:server).and_return("https://example.com")
    allow(k8_client).to receive(:get_namespaces).and_return([])
    allow(k8_client).to receive(:create_namespace).and_return(true)

    helm_service = double("K8::Helm::Service")
    allow(K8::Helm::Service).to receive(:create_from_add_on).and_return(helm_service)
    allow(helm_service).to receive_messages(
      get_endpoints: [],
      get_ingresses: [],
      friendly_name: "Test Add On",
      pods: [],
      revision: "1"
    )
  end

  describe "index" do
    it "lists existing add ons" do
      add_on = create(:add_on, cluster: cluster, name: "redis-cache", status: :installed)

      visit add_ons_path

      expect(page).to have_content("redis-cache")
      expect(page).to have_content("test-cluster")
    end
  end

  describe "create" do
    it "creates an add on via helm chart search" do
      # Load mock search response
      search_response = JSON.parse(File.read(Rails.root.join("spec/resources/helm/search/nginx.json")))

      # Mock the search endpoint
      search_result = OpenStruct.new(response: search_response, success?: true, failure?: false)
      allow(AddOns::HelmChartSearch).to receive(:execute).and_return(search_result)

      # Stub the helm chart details endpoint
      details_response = File.read(Rails.root.join("spec/resources/helm/details/nginx.json"))
      stub_request(:get, %r{artifacthub.io/api/v1/packages/helm/})
        .to_return(status: 200, body: details_response, headers: { "Content-Type" => "application/json" })

      # Stub the values.yaml fetch
      default_values = File.read(Rails.root.join("spec/resources/helm/default_values/nginx.yaml"))
      stub_request(:get, %r{artifacthub.io/api/v1/packages/.*/values})
        .to_return(status: 200, body: default_values, headers: { "Content-Type" => "text/plain" })

      # Stub the values schema fetch
      values_schema = File.read(Rails.root.join("spec/resources/helm/values_schema/nginx.json"))
      stub_request(:get, %r{artifacthub.io/api/v1/packages/.*/values-schema})
        .to_return(status: 200, body: values_schema, headers: { "Content-Type" => "application/json" })

      visit new_add_on_path

      fill_in "add_on_name", with: "my-nginx"
      select "test-cluster", from: "add_on_cluster_id"

      # Click on the Helm Chart card
      find("[data-card-name='helm_chart']").click

      # Type in the search box
      fill_in "add_on[metadata][helm_chart][helm_chart.name]", with: "ngin"

      # Wait for and select the first result (bitnami nginx)
      expect(page).to have_content("NGINX Open Source")
      find("h2", text: "nginx", match: :first).click

      # Verify the selection was made
      expect(page).to have_selector("[data-helm-chart-card]")

      click_button "Create Add On"

      expect(page).to have_content("Add on was successfully created")
      expect(AddOn.find_by(name: "my-nginx")).to be_present
    end
  end
end
