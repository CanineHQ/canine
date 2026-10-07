module AgentPostsHelper
  POST_KINDS = {
    "done" => { icon: "lucide:circle-check", color: "text-success", label: nil },
    "found" => { icon: "lucide:lightbulb", color: "text-info", label: "Found" },
    "needs_you" => { icon: "lucide:hand", color: "text-warning", label: "Needs you" },
    "problem" => { icon: "lucide:circle-alert", color: "text-error", label: "Problem" }
  }.freeze

  # Where a post links to: the step in the run that did it (the session page opens it and scrolls to it), and its
  # screenshot there
  def agent_post_path(post)
    path = agent_computer_agent_session_path(post.agent_computer, post.session, shot: post.agent_session_action_id)
    post.activity ? "#{path}##{dom_id(post.activity)}" : path
  end
end
