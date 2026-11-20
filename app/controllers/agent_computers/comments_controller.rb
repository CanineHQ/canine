# Comments on a post in the feed (AgentComputer::Comment). Each one starts a follow-up run that acts on it; the comment
# and, when the run ends, its reply stream into the post's thread (the feed's stream), so this only clears the form.
class AgentComputers::CommentsController < AgentComputers::BaseController
  def create
    post = @agent_computer.posts.find(params[:agent_post_id])
    return redirect_to(agent_computer_agent_posts_path(@agent_computer), alert: "Add an OpenRouter key first.") unless helpers.openrouter_key?

    comment = post.comments.new(body: params[:body].to_s.strip, user: current_user)
    return head(:unprocessable_entity) unless comment.save

    comment.act!
    render turbo_stream: turbo_stream.replace(helpers.dom_id(post, :comment_form), partial: "agent_computers/comments/form", locals: { post: })
  end
end
