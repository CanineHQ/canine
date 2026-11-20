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
      "--manager-namespace canine-system"
    )
  end
end
