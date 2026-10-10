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

  it "runs commands, window operations and terminal sessions through the other computer tools" do
    computer.running!
    computer_use = instance_double(AgentComputers::ComputerUse)
    allow(AgentComputers::ComputerUse).to receive(:new).and_return(computer_use)
    allow(computer_use).to receive(:run).with("uname -a", timeout: 30).and_return("exit_code" => 0, "stdout" => "Linux\n", "stderr" => "")
    allow(computer_use).to receive(:window).with("open_app", { command: "foot" }).and_return("window" => { "id" => "0x1", "app" => "foot" })
    allow(computer_use).to receive(:windows).and_return("windows" => [])

    run = Tools::ComputerRun.call(agent_computer_id: computer.id, command: "uname -a", server_context: context)
    expect(JSON.parse(run.content.first[:text])).to include("exit_code" => 0, "stdout" => "Linux\n")
    opened = Tools::ComputerWindows.call(agent_computer_id: computer.id, operation: "open_app", command: "foot", server_context: context)
    expect(JSON.parse(opened.content.first[:text]).dig("window", "id")).to eq("0x1")
    listed = Tools::ComputerWindows.call(agent_computer_id: computer.id, operation: "list", server_context: context)
    expect(JSON.parse(listed.content.first[:text])).to eq("windows" => [])

    allow(computer_use).to receive(:terminal).with("send", { session: "term1", text: "ls", enter: true }).and_return({})
    allow(computer_use).to receive(:terminal).with("wait", { session: "term1", timeout: 5 }).and_return("screen" => "~ $ ls")
    expect(Tools::ComputerTerminal.call(agent_computer_id: computer.id, operation: "send", session: "term1", text: "ls", enter: true,
                                        server_context: context).error?).to be false
    waited = Tools::ComputerTerminal.call(agent_computer_id: computer.id, operation: "wait", session: "term1", timeout_seconds: 5,
                                          server_context: context)
    expect(JSON.parse(waited.content.first[:text])).to eq("screen" => "~ $ ls")
  end
end
