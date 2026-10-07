require "rails_helper"

RSpec.describe "Agent feed", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:computer) do
    AgentComputer.create!(name: "desk", cluster: create(:cluster, account:), status: :running,
                          account_user: account.account_users.find_by(user: account.owner))
  end
  let(:task) { computer.agent_tasks.create!(name: "Inbox", instruction: "Handle requests", schedule: "0 * * * *", model: "test/model") }

  before do
    sign_in account.owner
    Flipper.enable(:agent_tasks, account)
  end

  it "shows a computer's posts newest first, with day headings, linking each to its step, and pages on" do
    stub_const("AgentPostsController::PER_PAGE", 2)
    [ 0, 1, 1 ].each_with_index do |days_ago, i|
      session = computer.agent_sessions.create!(agent_task: task, trigger: :manual, model: "test/model", status: :succeeded)
      step = session.activities.create!(position: 1, intent: "Adding", title: "Adding")
      session.posts.create!(agent_computer: computer, activity: step, kind: "done", text: "Post #{i}: [I did that].",
                            posted_at: days_ago.days.ago - i.minutes)
    end
    other = AgentComputer.create!(name: "other", cluster: create(:cluster, account:), status: :running,
                                 account_user: account.account_users.find_by(user: account.owner))
    other_session = other.agent_sessions.create!(trigger: :manual, model: "test/model", status: :succeeded)
    other_session.posts.create!(agent_computer: other, kind: "done", text: "Other computer post", posted_at: Time.current) # stays out
    get agent_computer_agent_posts_path(computer)

    expect(response.body).to include("Post 0", "Post 1", "I did that", "agent_feed_after_", "data-feed-day-at-value")
    expect(response.body).not_to include("Other computer post") # scoped to this computer
    expect(response.body).not_to include("Post 2") # on the next page
    first = AgentPost.find_by!(text: "Post 0: [I did that].")
    expect(response.body).to include("#{agent_computer_agent_session_path(computer, first.session)}#agent_session_activity_#{first.agent_session_activity_id}")

    last = AgentPost.find_by!(text: "Post 1: [I did that].")
    get agent_computer_agent_posts_path(computer, before_at: last.posted_at.iso8601(6), after_id: last.id),
        headers: { "Turbo-Frame" => "agent_feed_after_#{last.id}" }
    expect(response.body).to include("Post 2", "That's everything")
  end
end
