require "rails_helper"

RSpec.describe "Comments on agent posts", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:computer) do
    AgentComputer.create!(name: "desk", cluster: create(:cluster, account:), status: :running,
                          account_user: account.account_users.find_by(user: account.owner))
  end
  let(:task) { computer.tasks.create!(name: "Slack check", instruction: "Check Slack and answer questions", model: "openai/gpt-5.1", schedule: "0 * * * *", enabled: true) }
  let(:run) { task.sessions.create!(model: task.model, status: :succeeded, summary: "Answered Sean's question in #dev.", window_to: 2.hours.ago) }
  let(:feed_post) { run.posts.create!(text: "I noticed Sean asked about deploys, so [I answered him].", posted_at: 1.hour.ago) }

  before do
    sign_in account.owner
    Flipper.enable(:agent_computers, account)
    account.agent_provider_keys.create!(provider: "openrouter", api_key: "sk-or-v1-abcdef123456")
  end

  it "starts a follow-up run that gets the post's history, and shows the reply under the comment" do
    expect {
      post agent_computer_agent_post_comments_path(computer, feed_post), params: { body: "Also tell him about rollbacks" }, as: :turbo_stream
    }.to have_enqueued_job(AgentSessions::TurnJob)

    comment = feed_post.comments.reload.sole # (loaded, empty, when the post was broadcast)
    follow_up = comment.session
    expect(follow_up).to have_attributes(trigger: "comment", window_from: nil, window_to: nil, task:)
    expect(task.next_window_from).to be_within(1.second).of(run.window_to) # a follow-up doesn't move the schedule's window

    prompt = AgentLoop::SystemPrompt.build(follow_up)
    expect(prompt).to include("Also tell him about rollbacks", "Answered Sean's question in #dev.",
                              "[I answered him]. ← the post commented on")
    expect(prompt).not_to include("This run covers")

    follow_up.update!(status: :succeeded, summary: "Told Sean how rollbacks work.")
    get agent_computer_agent_posts_path(computer)
    expect(response.body).to include("Also tell him about rollbacks", "Told Sean how rollbacks work.")
  end

  it "tags a post like a reaction: one per person, changed by picking another, removed by clicking it again" do
    post agent_computer_agent_post_reaction_path(computer, feed_post), as: :turbo_stream
    expect(feed_post.reactions.reload.sole.tag).to eq("useful") # a plain click gives the first tag
    post agent_computer_agent_post_reaction_path(computer, feed_post), params: { tag: "wrong" }, as: :turbo_stream
    expect(feed_post.reactions.reload.sole.tag).to eq("wrong")
    expect(response.body).to include("Wrong")

    delete agent_computer_agent_post_reaction_path(computer, feed_post), as: :turbo_stream
    expect(feed_post.reactions.reload).to be_empty
  end
end
