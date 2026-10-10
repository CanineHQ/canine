require "rails_helper"

RSpec.describe AgentSessionsHelper, type: :helper do
  it "renders a summary's markdown, without HTML or unsafe links from what it quotes" do
    html = helper.agent_markdown("**No events today**\n\n- one\n- [ok](https://example.com) <script>alert(1)</script> [x](javascript:alert(1))")
    expect(html).to include("<strong>No events today</strong>", "<li>one</li>", '<a href="https://example.com">ok</a>')
    expect(html).not_to include("<script", 'href="javascript')
  end
end
