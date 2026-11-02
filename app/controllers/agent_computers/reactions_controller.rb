# Tagging a post in the feed (AgentComputer::Reaction): set or change your tag, or take it off. Answers with the post's
# action bar, re-drawn.
class AgentComputers::ReactionsController < AgentComputers::BaseController
  before_action :set_post

  def create
    reaction = @post.reactions.find_or_initialize_by(user: current_user)
    reaction.update!(tag: params[:tag].presence_in(AgentComputer::Reaction::TAGS.keys) || AgentComputer::Reaction::DEFAULT)
    render_bar
  end

  def destroy
    @post.reactions.where(user: current_user).delete_all
    render_bar
  end

  private

  def set_post
    @post = @agent_computer.posts.find(params[:agent_post_id])
  end

  def render_bar
    @post.reactions.reset
    render turbo_stream: turbo_stream.replace(helpers.dom_id(@post, :actions), partial: "agent_computers/posts/actions", locals: { post: @post })
  end
end
