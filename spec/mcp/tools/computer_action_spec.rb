# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::ComputerAction do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:) }
  let(:context) { { user_id: account_user.user_id } }

  it "passes actions to a running computer, returns screenshots as images, and refuses stopped or other accounts' computers" do
    computer.running!
    computer_use = instance_double(AgentComputers::ComputerUse)
    allow(AgentComputers::ComputerUse).to receive(:new).and_return(computer_use)
    allow(computer_use).to receive(:perform).with({ action: "left_click", coordinate: [ 10, 20 ] }).and_return({})
    allow(computer_use).to receive(:perform).with({ action: "screenshot" }).and_return("image" => "aW1n", "width" => 1920, "height" => 1080)

    expect(described_class.call(agent_computer_id: computer.id, action: "left_click", coordinate: [ 10, 20 ], server_context: context).error?).to be false

    screenshot = described_class.call(agent_computer_id: computer.id, action: "screenshot", server_context: context).content
    expect(screenshot.first).to eq(type: "image", data: "aW1n", mimeType: "image/png")
    expect(JSON.parse(screenshot.last[:text])).to eq("width" => 1920, "height" => 1080)

    computer.stopped!
    expect(described_class.call(agent_computer_id: computer.id, action: "screenshot", server_context: context).content.first[:text]).to include("start it first")

    stranger = { user_id: create(:account_user).user_id }
    expect(described_class.call(agent_computer_id: computer.id, action: "screenshot", server_context: stranger).error?).to be true
  end
end
