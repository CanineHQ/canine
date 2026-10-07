require "rails_helper"

RSpec.describe AgentSessions::TurnJob do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let(:task) do
    computer.agent_tasks.create!(name: "Inbox", instruction: "Check Slack", schedule: "0 * * * *", model: "test/model",
                                 spec: { "limits" => { "minutes" => 20 } })
  end

  it "stops a session that has run past its task's limit, without calling the model" do
    session = computer.agent_sessions.create!(agent_task: task, trigger: :manual, model: "test/model", status: :running, started_at: 21.minutes.ago)
    expect(Llm::OpenRouter).not_to receive(:new)

    described_class.perform_now(session)
    expect(session.reload).to have_attributes(status: "failed", error: "Stopped after 20 minutes (the task's limit).")
  end

  it "tries a turn again when the computer can't be reached, and gives up after the last try" do
    session = computer.agent_sessions.create!(agent_task: task, trigger: :manual, model: "test/model", status: :running)
    computer.account.agent_provider_keys.create!(provider: "openrouter", api_key: "key")
    allow(AgentComputers::PortForward).to receive(:open).and_raise(AgentComputers::PortForward::Error, "kubectl port-forward to desk didn't start")
    stub_const("ENV", ENV.to_h.merge("LANGFUSE_HOST" => "http://localhost:3100", "LANGFUSE_PUBLIC_KEY" => "pk", "LANGFUSE_SECRET_KEY" => "sk"))
    allow(AgentLoop::Trace::Exporter).to receive(:push) { |span| (@pushed ||= []) << span }

    expect { described_class.perform_now(session) }.to have_enqueued_job(described_class).with(session, 2)
    expect(session.reload).to be_running
    expect(@pushed.last.error.message).to eq("kubectl port-forward to desk didn't start") # the retried turn shows as failed

    described_class.perform_now(session, described_class::RETRIES)
    expect(session.reload).to have_attributes(status: "failed", error: "kubectl port-forward to desk didn't start")
  end
end
