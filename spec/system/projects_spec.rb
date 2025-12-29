require 'rails_helper'

RSpec.describe "Projects", type: :system do
  attr_reader :user, :account, :cluster

  before do
    result = sign_in_user
    @user = result[:user]
    @account = result[:account]
    @cluster = create(:cluster, account: account, name: "test-cluster")

    k8_client = instance_double(K8::Client)
    allow(K8::Client).to receive(:new).and_return(k8_client)
    allow(k8_client).to receive(:version).and_return({ 'serverVersion' => { 'gitVersion' => 'v1.28.0' } })
    allow(k8_client).to receive(:can_connect?).and_return(true)
    allow(k8_client).to receive(:server).and_return("https://example.com")
  end

  describe "index" do
    it "lists existing projects" do
      project = create(:project, cluster: cluster, account: account, name: "my-project")

      visit projects_path

      expect(page).to have_content("my-project")
      expect(page).to have_content("test-cluster")
    end
  end

  describe "show" do
    it "displays project deployments page" do
      project = create(:project, cluster: cluster, account: account, name: "production-app")

      visit project_path(project)

      expect(page).to have_content("production-app")
      expect(page).to have_content("Deployments")
    end
  end
end
