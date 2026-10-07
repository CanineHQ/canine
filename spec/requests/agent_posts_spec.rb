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

  it "shows posts newest first, each with its time for the day headings, linking each to its step, and pages on" do
    stub_const("AgentPostsController::PER_PAGE", 2)
    [ 0, 1, 1 ].each_with_index do |days_ago, i|
      session = computer.agent_sessions.create!(agent_task: task, trigger: :manual, model: "test/model", status: :succeeded)
      step = session.activities.create!(position: 1, intent: "Adding", title: "Adding")
      session.posts.create!(agent_computer: computer, activity: step, kind: "done", text: "Post #{i}: [I did that].",
                            posted_at: days_ago.days.ago - i.minutes)
    end
    other = create(:account) # another account's posts stay out
    get agent_posts_path

    expect(response.body).to include("Post 0", "Post 1", "I did that", "agent_feed_after_", "data-feed-day-at-value")
    expect(response.body).not_to include("Post 2") # on the next page
    first = AgentPost.find_by!(text: "Post 0: [I did that].")
    expect(response.body).to include("#{agent_computer_agent_session_path(computer, first.session)}#agent_session_activity_#{first.agent_session_activity_id}")

    last = AgentPost.find_by!(text: "Post 1: [I did that].")
    get agent_posts_path(before_at: last.posted_at.iso8601(6), after_id: last.id),
        headers: { "Turbo-Frame" => "agent_feed_after_#{last.id}" }
    expect(response.body).to include("Post 2", "That's everything")
    expect(other.agent_computers).to be_empty
  end
end
