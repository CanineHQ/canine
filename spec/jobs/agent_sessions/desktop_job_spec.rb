require "rails_helper"

RSpec.describe AgentSessions::DesktopJob do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let(:task) { computer.tasks.create!(name: "Extension", instruction: "Install it", schedule: "0 * * * *", model: "test/model") }
  let(:session) { task.sessions.create!(trigger: :manual, model: "test/model", status: :waiting_for_tool, workspace: 4) }
  let(:computer_use) { instance_double(AgentComputers::ComputerUse) }
  let(:client) { instance_double(Llm::OpenRouter) }
  let(:png) { "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" }

  def reply(name, args)
    Llm::OpenRouter::Reply.new({ "role" => "assistant", "tool_calls" => [ { "id" => "c1", "type" => "function",
                                                                             "function" => { "name" => name, "arguments" => args.to_json } } ] },
                               { input_tokens: 1000, output_tokens: 20, cost_usd: 0.01 })
  end

  before do
    account_user.account.agent_provider_keys.create!(api_key: "sk-or-test")
    allow(AgentComputers::ComputerUse).to receive(:new).and_return(computer_use)
    allow(Llm::OpenRouter).to receive(:new).and_return(client)
  end

  it "shows the run's workspace, acts step by step on the screen model, then gives the screen back and resumes the run" do
    computer.update!(browse_model: "openai/gpt-5.1", screen_model: "anthropic/claude-sonnet-5.5")
    activity = session.activities.create!(position: 1, intent: "Installing", title: "Installing", started_at: Time.current)
    parent = activity.actions.create!(tool: "desktop", status: :running, started_at: Time.current,
                                      arguments: { "task" => "Turn on Developer mode", "reason" => "browser_internal_page", "url" => "chrome://extensions" })
    expect(AgentLoop::Desktop.start(session, parent.arguments)).to have_attributes(signal: :waiting_for_tool)
    other = task.sessions.create!(trigger: :manual, model: "test/model", status: :running)
    expect(AgentLoop::Desktop.start(other, parent.arguments).text).to include("Another run is using the screen")

    allow(computer_use).to receive(:workspaces).and_return("workspaces" => [ { "workspace" => 1, "visible" => true } ])
    expect(computer_use).to receive(:window).with("open_url", url: "chrome://extensions", workspace: 4, maximize: true).ordered
    expect(computer_use).to receive(:window).with("switch_workspace", workspace: 4).ordered
    expect(computer_use).to receive(:window).with("switch_workspace", workspace: 1).ordered
    allow(computer_use).to receive(:perform).with(action: "screenshot").and_return("image" => png, "width" => 1280, "height" => 800)
    expect(computer_use).to receive(:perform).with({ "action" => "left_click", "coordinate" => [ 1200, 90 ] })
    allow(client).to receive(:chat).with(hash_including(model: "anthropic/claude-sonnet-5.5")).and_return(
      reply("computer", { action: "left_click", coordinate: [ 1200, 90 ], why: "Turn on Developer mode" }),
      reply("done", { success: true, result: "Developer mode is on." })
    )

    described_class.perform_now(session)
    expect(parent.reload.steps.sole).to have_attributes(label: "Left click at (1200, 90) · Turn on Developer mode", screenshot_moment: "before")
    expect(parent.reload).to have_attributes(status: "done")
    expect(session.reload).to have_attributes(status: "running", input_tokens: 2000)
    expect(session.messages.last.content).to eq("The desktop task finished: Developer mode is on.")
    expect(computer.reload.screen_session).to be_nil
  end
end
