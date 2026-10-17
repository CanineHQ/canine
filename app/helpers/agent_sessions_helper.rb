module AgentSessionsHelper
  # The status badge's text. waiting_for_tool covers any async tool, so name the one actually running (browse or the
  # coding agent) rather than always saying "coding agent".
  def agent_session_status_label(session)
    case session.status
    when "waiting_for_human" then "paused: you're using the computer"
    when "waiting_for_tool"
      case session.actions.last&.tool
      when "delegate" then "coding agent working"
      when "browse", "browse_step" then "browsing the web"
      else "working"
      end
    else session.status
    end
  end

  # What a run in progress is doing now, for its card in the feed
  def agent_session_doing(session)
    case session.status
    when "queued" then "Starting"
    when "running" then "Thinking"
    when "waiting_for_human" then "Waiting for you: you're using the computer"
    else agent_session_status_label(session).upcase_first
    end
  end

  # Markdown from the model (a session's summary) as HTML. The text can quote emails and web pages, so raw HTML is
  # dropped, links must be http(s) or mailto, and the result is sanitized as well.
  def agent_markdown(text)
    renderer = Redcarpet::Render::HTML.new(filter_html: true, no_images: true, safe_links_only: true,
                                           link_attributes: { target: "_blank", rel: "noopener noreferrer" })
    markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true, fenced_code_blocks: true, strikethrough: true,
                                                 no_intra_emphasis: true, lax_spacing: true)
    sanitize(markdown.render(text.to_s))
  end
end
