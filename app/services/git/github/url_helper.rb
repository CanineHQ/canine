class Git::Github::UrlHelper
  HOST = Rails.application.routes.default_url_options[:host]

  def self.authorize_url(redirect_uri)
    params = {
      response_type: "code",
      client_id: ENV["OMNIAUTH_GITHUB_PUBLIC_KEY"],
      scope: "id emailname",
      state: SecureRandom.uuid
    }
    uri = URI::HTTPS.build(host: "github.com", path: "/login/oauth/authorize", query: params.to_query)
    uri.query += "&redirect_uri=#{redirect_uri}"
    uri.to_s
  end
end
