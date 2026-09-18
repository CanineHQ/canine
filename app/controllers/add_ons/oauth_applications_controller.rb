class AddOns::OauthApplicationsController < AddOns::BaseController
  def create
    unless @add_on.oauth_application.present?
      @add_on.create_oauth_application!(
        name: "Auth Proxy: #{@add_on.name}",
        redirect_uri: "#{ENV.fetch('APP_HOST')}/oauth2/callback",
        scopes: "openid profile email",
        confidential: true
      )
    end

    deploy_auth_proxy if @add_on.installed?

    redirect_to edit_add_on_path(@add_on), notice: "SSO protection enabled."
  end

  def destroy
    @add_on.oauth_application&.destroy
    AddOns::CleanupAuthProxyJob.perform_later(@add_on) if @add_on.installed?

    redirect_to edit_add_on_path(@add_on), notice: "SSO protection removed."
  end

  private

  def deploy_auth_proxy
    ingresses = @service.get_ingresses
    endpoints = @service.get_endpoints
    kubectl = K8::Kubectl.new(active_connection)

    ingresses.each do |ingress|
      endpoint = endpoints.find { |e| e.metadata.name == ingress.metadata.name }
      next unless endpoint

      domains = ingress.spec.rules.map(&:host).compact
      next if domains.empty?

      port = endpoint.spec.ports.first&.port
      next unless port

      @add_on.oauth_application.update!(redirect_uri: "https://#{domains.first}/oauth2/callback")
      kubectl.apply_yaml(
        K8::AddOns::AuthProxy.new(@add_on, endpoint, port, domains).to_yaml
      )
      kubectl.apply_yaml(
        K8::AddOns::Ingress.new(@add_on, endpoint, port, domains).to_yaml
      )
    end
  end
end
