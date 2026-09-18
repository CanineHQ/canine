class InternalSso::DeployAddOnProxy
  extend LightService::Action

  expects :add_on, :connection

  executed do |context|
    add_on = context.add_on

    next context unless add_on.internal? && add_on.installed?

    service = K8::Helm::Service.create_from_add_on(context.connection)
    ingresses = service.get_ingresses
    endpoints = service.get_endpoints
    kubectl = K8::Kubectl.new(context.connection)

    ingresses.each do |ingress|
      endpoint = endpoints.find { |e| e.metadata.name == ingress.metadata.name }
      next unless endpoint

      domains = ingress.spec.rules.map(&:host).compact
      next if domains.empty?

      port = endpoint.spec.ports.first&.port
      next unless port

      add_on.oauth_application.update!(redirect_uri: "https://#{domains.first}/oauth2/callback")
      kubectl.apply_yaml(
        K8::AddOns::AuthProxy.new(add_on, endpoint, port, domains).to_yaml
      )
      kubectl.apply_yaml(
        K8::AddOns::Ingress.new(add_on, endpoint, port, domains).to_yaml
      )
    end
  end
end
