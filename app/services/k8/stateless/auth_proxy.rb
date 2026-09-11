class K8::Stateless::AuthProxy < K8::Base
  attr_accessor :service, :project

  def initialize(service)
    @service = service
    @project = service.project
  end

  def issuer_url
    Rails.application.credentials.dig(:app, :host) || "https://canine.sh"
  end

  def client_id
    service.effective_oauth_application&.uid
  end

  def client_secret
    service.effective_oauth_application&.secret
  end

  def cookie_secret
    service.auth_proxy_cookie_secret
  end
end
