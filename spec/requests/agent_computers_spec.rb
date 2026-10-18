require "rails_helper"

RSpec.describe "Agent computers", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:computer) do
    AgentComputer.create!(name: "desk", cluster: create(:cluster, account:), account_user: account.account_users.find_by(user: account.owner))
  end

  before { sign_in account.owner }

  it "shows provisioning's progress as it goes, and why it failed after" do
    computer.update!(status: :provisioning, provision_stage: 2)
    computer.info("Installing Omarchy (usually 5-10 minutes)...")
    get edit_agent_computer_path(computer)
    expect(response.body).to include("Installing Omarchy", "Show setup logs", "usually takes 15-25 minutes")

    computer.fail!(RuntimeError.new("Not enough free memory on the cluster"))
    get edit_agent_computer_path(computer)
    expect(response.body).to include("Not enough free memory on the cluster", "Installing Omarchy (usually")
    expect(response.body).not_to include("usually takes 15-25 minutes")
  end
end
