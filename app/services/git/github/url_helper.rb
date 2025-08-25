class Git::Github::UrlHelper
  def self.authorize_url
    base_url = "https://github.com/login/oauth/authorize"
    params = {
      response_type: "code",
      client_id: ENV["OMNIAUTH_GITHUB_PUBLIC_KEY"],
      redirect_uri: Rails.application.routes.url_helpers.github_oauth_url(host: Rails.application.routes.default_url_options[:host]),
      scope: "id email name",
      state: SecureRandom.uuid
    }
    "#{base_url}?#{params.to_query}"
  end
end
