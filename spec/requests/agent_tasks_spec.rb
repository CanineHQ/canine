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
    expect(response).to redirect_to(agent_computer_agent_tasks_path(computer)) # a computer opens on its tasks

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
end
