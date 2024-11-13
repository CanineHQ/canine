class StaticController < ApplicationController
  MANIFESTO_FILE = Rails.root.join("public", "manifesto.md")
  INSTALL_SCRIPT = "curl -sSL https://raw.githubusercontent.com/czhu12/canine/refs/heads/main/install/install.sh | bash"
  skip_before_action :authenticate_user!

  def index
  end

  def manifesto
    @content = File.read(MANIFESTO_FILE)
    renderer = Redcarpet::Render::HTML.new
    @markdown = Redcarpet::Markdown.new(renderer, tables: true)
  end
end
