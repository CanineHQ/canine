# Serves /llms.txt: a plain-text guide that lets an AI agent onboard a user and drive Canine through the REST API.
class LlmsController < ActionController::Base
  def show
    @base_url = request.base_url
    render formats: :text, content_type: "text/plain"
  end
end
