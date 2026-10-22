require "rails_helper"

RSpec.describe "Agent computers", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:computer) do
    AgentComputer.create!(name: "desk", cluster: create(:cluster, account:), account_user: account.account_users.find_by(user: account.owner))
  end

  before do
    sign_in account.owner
    Flipper.enable(:agent_computers, account)
  end

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

  it "only puts a computer on one of the account's clusters, and never moves it after" do
    others = create(:cluster, account: create(:account), status: :running)
    ours = create(:cluster, account:, status: :running)
    [ others, ours ].each { |c| ClusterPackage.create!(cluster: c, name: "kubevirt", status: :installed) }

    expect {
      post agent_computers_path, params: { agent_computer: { name: "sneaky", cluster_id: others.id } }
    }.not_to change(AgentComputer, :count)
    expect {
      post agent_computers_path, params: { agent_computer: { name: "mine", cluster_id: ours.id } }
    }.to change(AgentComputer, :count).by(1)

    get agent_computers_path
    expect(response.body).to include("mine", ours.name, "New Computer")

    patch agent_computer_path(computer), params: { agent_computer: { name: "moved", cluster_id: others.id, coding_agent: "pi" } }
    expect(computer.reload).to have_attributes(name: "desk", cluster: computer.cluster, coding_agent: "pi")
  end

  it "reserves the memory picked, recommending 8Gi, and applies a change on the next start" do
    get new_agent_computer_path
    expect(response.body).to include("16Gi", "Recommended")

    computer.update!(status: :running)
    patch agent_computer_path(computer), params: { agent_computer: { memory: "16Gi" } }
    expect(flash[:notice]).to eq("Memory set to 16Gi. Stop and start the computer to apply it.")
    expect(AgentComputers::Omarchy.new(computer.reload).virtual_machine_yaml({})).to include("guest: 16Gi")

    patch agent_computer_path(computer), params: { agent_computer: { memory: "1Ti" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(computer.reload.memory).to eq("16Gi")
  end
end
