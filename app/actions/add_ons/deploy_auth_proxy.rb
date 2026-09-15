class AddOns::DeployAuthProxy
  extend LightService::Action
  expects :add_on, :was_internal, :connection

  executed do |context|
    add_on = context.add_on

    # Clean up auth proxy resources if internal was toggled off
    if context.was_internal && !add_on.internal?
      AddOns::CleanupAuthProxyJob.perform_later(add_on) if add_on.installed?
      next context
    end

    # Skip if not internal or add-on isn't installed yet
    next context unless add_on.internal? && add_on.installed?

    kubectl = K8::Kubectl.new(context.connection)
    service = K8::Helm::Service.create_from_add_on(context.connection)
    ingresses = service.get_ingresses
    endpoints = service.get_endpoints

    ingresses.each do |ingress|
      endpoint = endpoints.find { |e| e.metadata.name == ingress.metadata.name }
      next unless endpoint

      domains = ingress.spec.rules.map(&:host).compact
      next if domains.empty?

      port = endpoint.spec.ports.first&.port
      next unless port

      if add_on.internal? && add_on.oauth_application.present?
        add_on.oauth_application.update(redirect_uri: "https://#{domains.first}/oauth2/callback")
        kubectl.apply_yaml(K8::AddOns::AuthProxy.new(add_on, endpoint, port, domains).to_yaml)
      end

      kubectl.apply_yaml(K8::AddOns::Ingress.new(add_on, endpoint, port, domains).to_yaml)
    end
  end
end
