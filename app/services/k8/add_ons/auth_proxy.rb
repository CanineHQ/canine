class K8::AddOns::AuthProxy < K8::Base
  attr_reader :add_on, :endpoint, :port, :domains

  def initialize(add_on, endpoint, port, domains)
    @add_on = add_on
    @endpoint = endpoint
    @port = port
    @domains = domains
  end

  def issuer_url
    Rails.application.credentials.dig(:app, :host) || "https://canine.sh"
  end

  def client_id
    add_on.oauth_application&.uid
  end

  def client_secret
    add_on.oauth_application&.secret
  end

  def cookie_secret
    add_on.auth_proxy_cookie_secret
  end
end
