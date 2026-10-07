require "rails_helper"

RSpec.describe AgentLoop::Posts do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let(:task) { computer.agent_tasks.create!(name: "Inbox", instruction: "Handle access requests", schedule: "0 * * * *", model: "test/model") }
  let(:session) do
    computer.agent_sessions.create!(agent_task: task, trigger: :manual, model: "test/model", status: :succeeded,
                                    summary: "Added Sean to Persona.", finished_at: Time.current)
  end
  let(:client) { instance_double(Llm::OpenRouter) }
  let(:png) { Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==") }

  before do
    account_user.account.agent_provider_keys.create!(api_key: "sk-or-test")
    allow(Llm::OpenRouter).to receive(:new).and_return(client)
  end

  it "writes a run's posts, linked to the step and screenshot that show them, replacing any from before" do
    slack, persona = [ "Reading Slack", "Adding Sean to Persona" ].map.with_index(1) do |title, position|
      session.activities.create!(position:, intent: title, title:, started_at: 1.minute.ago, finished_at: Time.current)
    end
    shots = [ slack, persona ].map do |activity|
      session.actions.create!(activity:, tool: "computer_accessibility", arguments: { "operation" => "press" }, status: :done)
             .tap { |a| a.screenshot.attach(io: StringIO.new(png), filename: "shot.png", content_type: "image/png") }
    end
    session.posts.create!(agent_computer: computer, kind: "done", text: "old", posted_at: 1.day.ago)
    allow(client).to receive(:chat).and_return(Llm::OpenRouter::Reply.new({ "content" => { posts: [
      { kind: "done", text: "I noticed Sean asked to be added to Persona, so [I added him].", activity_id: persona.id, screenshot_id: nil },
      { kind: "needs_you", text: "Dan wants a CSV export; [I left it for you].", activity_id: slack.id, screenshot_id: shots.first.id },
      { kind: "gossip", text: "not a kind", activity_id: slack.id }
    ] }.to_json }, { cost_usd: 0.0002 }))

    described_class.call(session)
    posts = session.posts.reload.newest_first.to_a
    expect(posts.map(&:kind)).to eq(%w[done needs_you])
    expect(posts.first).to have_attributes(activity: persona, action: shots.last) # no screenshot chosen: the step's last
    expect(posts.first.parts).to eq([ "I noticed Sean asked to be added to Persona, so ", "I added him", "." ])
    expect(posts.second.action).to eq(shots.first)
    expect(session.reload.cost_usd).to eq(0.0002)
  end
end
