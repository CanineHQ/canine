# The agent feed: what the account's agents did, found and left for the person, newest first, across all its
# computers and tasks (AgentPost, written after each run by AgentLoop::Posts). It scrolls on forever: each page ends
# with a lazy frame that loads the next. The browser groups posts under the day they're from, in its own time zone
# (feed_day_controller.js).
class AgentPostsController < ApplicationController
  include AgentTasksFeature

  PER_PAGE = 15

  def index
    posts = AgentPost.where(agent_computer: current_account.agent_computers).newest_first
                     .includes(:agent_computer, :activity, session: :agent_task, action: { screenshot_attachment: :blob })
    posts = after_cursor(posts) if params[:before_at]
    @posts = posts.limit(PER_PAGE + 1).to_a
    @more = @posts.size > PER_PAGE
    @posts = @posts.first(PER_PAGE)
    render partial: "agent_posts/page", locals: { posts: @posts, more: @more } if turbo_frame_request?
  end

  private

  # The posts after the last one shown, in feed order (newest first; a run's posts in the order they were written)
  def after_cursor(posts)
    at = Time.zone.parse(params[:before_at].to_s)
    return posts unless at

    posts.where("agent_posts.posted_at < :at OR (agent_posts.posted_at = :at AND agent_posts.id > :id)", at:, id: params[:after_id].to_i)
  end
end
