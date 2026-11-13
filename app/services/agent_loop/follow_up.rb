module AgentLoop
  # A run started by a comment on a post (AgentComputer::Comment): the post's history, so the agent can work out what
  # the comment refers to and what's already done. That's the run the post came from (its summary, posts and steps),
  # and the comments before this one with what their runs did. Replaces the task's own instruction in the system prompt.
  module FollowUp
    def self.prompt(comment)
      post = comment.post
      run = post.session
      earlier = post.comments.where(id: ...comment.id).order(:id).includes(:user, :session)
      <<~TEXT.strip
        The person commented on a post in their feed, and their comment is your task now. The post came from a run of
        their task "#{run.task.name}": #{run.task.instruction}

        That run (#{run.created_at.utc.iso8601}, #{run.status}) summed up its work as:
        #{run.summary.presence || run.error.presence || "(no summary)"}

        Its posts:
        #{run.posts.order(:position).map { |p| "- #{p.text}#{" ← the post commented on" if p.id == post.id}" }.join("\n")}

        What it did, step by step:
        #{run.activities.map { |a| "- #{a.title}#{" → #{a.outcome}" if a.outcome.present?}" }.join("\n").presence || "(no steps)"}
        #{thread(earlier)}
        The person's comment:
        #{comment.body}

        Use that history to work out what they mean (who "him" is, which message "that" was) and what's already been
        done, and do what they ask. Don't redo work that's done unless they ask you to. If the history isn't enough to
        act safely, look it up on the computer, and if it still isn't clear, finish and say what you need to know.
      TEXT
    end

    def self.thread(comments)
      return "" if comments.empty?

      lines = comments.map do |c|
        reply = c.session && (c.session.summary.presence || c.session.error.presence || c.session.status)
        "- #{c.user.email}: #{c.body}#{"\n  Its follow-up run: #{reply}" if reply}"
      end
      "\nEarlier comments on the post, oldest first:\n#{lines.join("\n")}\n"
    end
  end
end
