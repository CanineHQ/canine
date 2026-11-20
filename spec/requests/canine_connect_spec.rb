require "rails_helper"

RSpec.describe "Canine Connect", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }

  before { sign_in account.owner }

  it "links both macOS downloads and shows which clusters are ready" do
    create(:cluster, account:, name: "ready-cluster").cluster_packages.create!(name: "telepresence", status: :installed)
    create(:cluster, account:, name: "bare-cluster")

    get canine_connect_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      CanineConnectRelease.download_url("arm64"),
      CanineConnectRelease.download_url("x86_64"),
      "ready-cluster", "bare-cluster", "Install Telepresence package",
      "--manager-namespace canine-system",
      # Hands the app this Canine's own address, which is not always canine.sh
      ERB::Util.html_escape(CanineConnectRelease.open_url("http://www.example.com")),
      # The command line steps offer the kubeconfig of a cluster that can actually be connected to
      "Download kubeconfig for ready-cluster"
    )
    expect(CanineConnectRelease.open_url("https://canine.acme.internal:8443")).to eq("canine-connect://connect?url=https%3A%2F%2Fcanine.acme.internal%3A8443")

    get "/private-networking"
    expect(response).to redirect_to(canine_connect_path)
  end

  it "has a public landing page" do
    sign_out account.owner

    get "/private-networking"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(CanineConnectRelease.download_url("arm64"), CanineConnectRelease.download_url("x86_64"), "http://www.example.com/private-networking")
    expect(response.body).not_to include("https://canine.sh")
    # The page sells the outcome, not the app's name
    expect(response.body).not_to include("Canine Connect")
  end
end
