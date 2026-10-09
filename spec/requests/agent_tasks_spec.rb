require "rails_helper"

RSpec.describe "Agent tasks and sessions", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:computer) do
    AgentComputer.create!(name: "desk", cluster: create(:cluster, account:), status: :running,
                          account_user: account.account_users.find_by(user: account.owner))
  end

  before do
    sign_in account.owner
    Flipper.enable(:agent_tasks, account)
  end

  it "is hidden, and its pages don't exist, without the agent_tasks flag" do
    Flipper.disable(:agent_tasks, account)
    get agent_computer_path(computer)
    expect(response).to redirect_to(edit_agent_computer_path(computer)) # the machine page, not tasks
    get edit_agent_computer_path(computer)
    expect(response.body).not_to include(agent_computer_agent_tasks_path(computer))
    get agent_computer_agent_tasks_path(computer)
    expect(response).to have_http_status(:not_found)
    get agent_provider_keys_path
    expect(response).to have_http_status(:not_found)
  end

  it "saves a key, creates a task from the form, runs it, and shows the session" do
    get agent_computer_path(computer)
    expect(response).to redirect_to(agent_computer_agent_posts_path(computer)) # a computer opens on its feed

    post agent_provider_keys_path, params: { agent_provider_key: { provider: "openrouter", api_key: "sk-or-v1-abcdef123456" } }
    get agent_provider_keys_path
    expect(response.body).to include("sk-or-…3456")
    expect(response.body).not_to include("sk-or-v1-abcdef123456")

    get new_agent_computer_agent_task_path(computer)
    expect(response.body).to include("Draft from this", "blocked_commands")

    # Draft compiles the instruction, saves it (not enabled) and redirects to review it
    draft = AgentLoop::Compiler::Draft.new(name: "Slack check", schedule: "0 * * * *", spec: AgentLoop::Spec.normalize("never" => [ "merge" ]))
    allow(AgentLoop::Compiler).to receive(:compile).and_return(draft)
    post draft_agent_computer_agent_tasks_path(computer), params: { agent_task: { instruction: "Every hour, check Slack" } }
    drafted = computer.agent_tasks.sole
    expect(response).to redirect_to(edit_agent_computer_agent_task_path(computer, drafted))
    expect(drafted).to have_attributes(enabled: false, schedule: "0 * * * *")
    drafted.destroy!

    post agent_computer_agent_tasks_path(computer), params: { agent_task: {
      instruction: "Every hour, check Slack", name: "Slack check", schedule: "0 * * * *", model: "test/model", enabled: "1",
      spec_yaml: "sources:\n- 'Slack: #akula-dev'\nnever:\n- merge pull requests\n"
    } }
    task = computer.agent_tasks.sole
    expect(task.spec).to include("sources" => [ "Slack: #akula-dev" ], "never" => [ "merge pull requests" ])
    expect(task.next_run_at).to be > Time.current

    post run_now_agent_computer_agent_task_path(computer, task)
    session = task.sessions.sole
    expect(response).to redirect_to(agent_computer_agent_session_path(computer, session))
    get agent_computer_agent_session_path(computer, session)
    expect(response.body).to include("Slack check", "No screenshots yet")
    # The task list shows the schedule in words and recent runs, not the model; the task's page shows its definition
    # and its runs; the old sessions list sends you to the tasks
    get agent_computer_agent_tasks_path(computer)
    expect(response.body).to include("Runs every hour", agent_computer_agent_session_path(computer, session))
    expect(response.body).not_to include("test/model")
    get agent_computer_agent_task_path(computer, task)
    expect(response.body).to include("Slack check", "Slack: #akula-dev", "Runs every hour", agent_computer_agent_session_path(computer, session))
    get agent_computer_agent_sessions_path(computer)
    expect(response).to redirect_to(agent_computer_agent_tasks_path(computer))
  end
  describe "composing from the feed" do
    it "runs an instruction now as a one-off task, and schedules one from a preset" do
      # Run now: creates a one-off (no schedule), starts a session, redirects to it.
      expect {
        post compose_agent_computer_agent_tasks_path(computer), params: { instruction: "Summarize my email", every: "now" }
      }.to change { computer.agent_tasks.count }.by(1).and change { computer.agent_sessions.count }.by(1)
      task = computer.agent_tasks.order(:created_at).last
      expect(task.schedule).to be_nil
      expect(task.enabled?).to be(false)
      # Stays on the feed, where the running session shows at the top.
      expect(response).to redirect_to(agent_computer_agent_posts_path(computer))
      get agent_computer_agent_posts_path(computer)
      expect(response.body).to include("Working…")

      # Schedule: a preset becomes a cron, enabled, and no session starts now.
      expect {
        post compose_agent_computer_agent_tasks_path(computer), params: { instruction: "Check issues", every: "1h" }
      }.to change { computer.agent_tasks.count }.by(1).and change { computer.agent_sessions.count }.by(0)
      scheduled = computer.agent_tasks.order(:created_at).last
      expect(scheduled.schedule).to eq("0 * * * *")
      expect(scheduled.enabled?).to be(true)

      # Feed renders the compose box and the scheduled task in the sidebar.
      get agent_computer_agent_posts_path(computer)
      expect(response.body).to include("What should your agent do?", "Scheduled", "Check issues")
    end

    it "builds a daily cron from the time, and won't run now when the computer is stopped" do
      post compose_agent_computer_agent_tasks_path(computer), params: { instruction: "Morning digest", every: "daily", daily_time: "08:30" }
      expect(computer.agent_tasks.order(:created_at).last.schedule).to eq("30 8 * * *")

      computer.update!(status: :stopped)
      expect {
        post compose_agent_computer_agent_tasks_path(computer), params: { instruction: "do it", every: "now" }
      }.not_to change { computer.agent_tasks.count }
      expect(flash[:alert]).to match(/must be running/)
    end

    it "queues a run behind the one already going, and starts it when that finishes" do
      post compose_agent_computer_agent_tasks_path(computer), params: { instruction: "first", every: "now" }
      first = computer.agent_sessions.sole

      expect {
        post compose_agent_computer_agent_tasks_path(computer), params: { instruction: "second", every: "now" }
      }.to change { computer.agent_sessions.count }.by(1)
      second = computer.agent_sessions.order(:created_at).last
      expect(second).to be_queued
      expect(second.waiting_in_queue?).to be(true)
      expect(flash[:notice]).to match(/Queued/)
      get agent_computer_agent_posts_path(computer)
      expect(response.body).to include("Queued")

      expect { first.finish!(:succeeded, summary: "done") }.to have_enqueued_job(AgentSessions::TurnJob).with(second)
    end
  end
  describe "machine model settings" do
    it "saves on the machine page, and new runs inherit the models" do
      patch agent_computer_path(computer), params: { agent_computer: {
        planning_model: "openai/gpt-5-mini", coding_model: "deepseek/deepseek-v4.1-flash", coding_agent: "pi" } }
      computer.reload
      expect(computer.planning_model).to eq("openai/gpt-5-mini")
      expect(computer.coding_agent).to eq("pi")

      # A task composed now starts on the machine's planning model.
      post compose_agent_computer_agent_tasks_path(computer), params: { instruction: "do x", every: "1h" }
      task = computer.agent_tasks.order(:created_at).last
      expect(task.model).to eq("openai/gpt-5-mini")

      # Delegate falls back to the machine's coding model and agent when the task doesn't override.
      session = computer.agent_sessions.create!(agent_task: task, trigger: :manual, model: task.model)
      run = AgentLoop::Delegate.command(session, {}, "~/x").first
      expect(run).to include("deepseek/deepseek-v4.1-flash").and include("pi ")
    end
  end
end
