module AgentSessionsHelper
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
