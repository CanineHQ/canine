require "rails_helper"

RSpec.describe "Agent feed", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:computer) do
    AgentComputer.create!(name: "desk", cluster: create(:cluster, account:), status: :running,
                          account_user: account.account_users.find_by(user: account.owner))
  end
  let(:task) { computer.tasks.create!(name: "Inbox", instruction: "Handle requests", schedule: "0 * * * *", model: "test/model") }

  before do
    sign_in account.owner
    Flipper.enable(:agent_computers, account)
  end

  it "shows a computer's posts newest first, with day headings, the header linking to the task, and pages on" do
    stub_const("AgentComputers::PostsController::PER_PAGE", 2)
    [ 0, 1, 1 ].each_with_index do |days_ago, i|
      session = computer.sessions.create!(task: task, trigger: :manual, model: "test/model", status: :succeeded)
      step = session.activities.create!(position: 1, intent: "Adding", title: "Adding")
      session.posts.create!(agent_computer: computer, activity: step, kind: "done", text: "Post #{i}: [I did that].",
                            posted_at: days_ago.days.ago - i.minutes)
    end
    other = AgentComputer.create!(name: "other", cluster: create(:cluster, account:), status: :running,
                                 account_user: account.account_users.find_by(user: account.owner))
    other_session = other.sessions.create!(trigger: :manual, model: "test/model", status: :succeeded)
    other_session.posts.create!(agent_computer: other, kind: "done", text: "Other computer post", posted_at: Time.current) # stays out
    get agent_computer_agent_posts_path(computer)

    expect(response.body).to include("Post 0", "Post 1", "I did that", "agent_feed_after_", "data-agent-computers--feed-day-at-value")
    expect(response.body).not_to include("Other computer post") # scoped to this computer
    expect(response.body).not_to include("Post 2") # on the next page
    expect(response.body).to include(agent_computer_agent_task_path(computer, task)) # header links to the task

    last = AgentComputer::Post.find_by!(text: "Post 1: [I did that].")
    get agent_computer_agent_posts_path(computer, before_at: last.posted_at.iso8601(6), after_id: last.id),
        headers: { "Turbo-Frame" => "agent_feed_after_#{last.id}" }
    expect(response.body).to include("Post 2", "That's everything")
  end

  it "says what a run in progress is doing and when it last moved, and arms the stuck warning" do
    session = computer.sessions.create!(task:, trigger: :scheduled, model: "test/model", status: :waiting_for_tool, workspace: 2,
                                        started_at: 40.minutes.ago)
    activity = session.activities.create!(position: 1, intent: "Reading Slack", title: "Reading Slack")
    session.actions.create!(activity:, tool: "browse", arguments: {}, status: :running, started_at: 31.minutes.ago,
                            created_at: 31.minutes.ago, updated_at: 31.minutes.ago)
    get agent_computer_agent_posts_path(computer)

    expect(response.body).to include("Browsing the web · last step", "31 minutes ago", "may be stuck", 'data-agent-computers--stalled-after-value="600"')
    expect(response.body).not_to include("Working…")
  end

  it "loads a finished activity's actions when it's opened on the session page" do
    session = computer.sessions.create!(task:, trigger: :manual, model: "test/model", status: :succeeded)
    activity = session.activities.create!(position: 1, intent: "Paying", title: "Paying", finished_at: Time.current)
    session.actions.create!(activity:, tool: "browse_step", arguments: { "did" => [ "Clicked “Pay invoice”" ] }, status: :done)
    get agent_computer_agent_session_activity_path(computer, session, activity)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Clicked “Pay invoice”")
  end
end
