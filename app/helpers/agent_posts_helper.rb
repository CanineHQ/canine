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

  # A `[phrase]` highlight marker; split keeps it as its own token (the group captures).
  POST_BRACKET = %r{(\[[^\]]+\])}
  # A bare URL (stops at whitespace, brackets, or angle brackets).
  POST_URL = %r{(https?://[^\s<>\[\]]+)}

  # The post text as safe HTML, Twitter-style: `[phrase]` markers become bold and bare URLs become links (shortened
  # when long). A URL inside a `[phrase]` is still linked. safe_join escapes every plain-text token, so the untrusted
  # body can't inject markup.
  def agent_post_body(post)
    safe_join(post.text.split(POST_BRACKET).map do |segment|
      if segment =~ /\A\[([^\]]+)\]\z/
        content_tag(:span, linkify_urls(Regexp.last_match(1)), class: "font-medium text-base-content")
      else
        linkify_urls(segment)
      end
    end)
  end

  # Turn the bare URLs in a plain-text run into links, leaving the rest as (escaped) text.
  def linkify_urls(text)
    safe_join(text.split(POST_URL).map do |token|
      next token unless token.start_with?("http://", "https://")

      # Trailing sentence punctuation (the "." or ")" after a URL) isn't part of the link.
      url, trailing = token.match(/\A(.*?)([.,;:!?)]*)\z/m).captures
      safe_join([ link_to(shorten_url(url), url, target: "_blank", rel: "noopener noreferrer",
                          class: "link link-primary break-all"), trailing ])
    end)
  end

  # A URL trimmed for display the way Twitter does: drop the scheme (and www.), keep the host, and ellipsize the path
  # once it runs long so you still see where the link goes.
  def shorten_url(url, max: 30)
    rest = url.sub(%r{\Ahttps?://(www\.)?}i, "").chomp("/")
    return rest if rest.length <= max

    host, path = rest.split("/", 2)
    return "#{rest[0, max - 1]}…" if path.nil? || host.length >= max - 1

    "#{host}/#{path[0, max - host.length - 2]}…"
  end
end
