class AddOns::ApplyEndpointIngress
  extend LightService::Action
  expects :add_on, :was_internal, :connection, :endpoint, :domains, :port

  executed do |context|
    add_on = context.add_on
    kubectl = K8::Kubectl.new(context.connection)

    if context.was_internal && !add_on.internal?
      AddOns::CleanupAuthProxyJob.perform_later(add_on) if add_on.installed?
    elsif add_on.internal? && add_on.oauth_application.present?
      add_on.oauth_application.update!(redirect_uri: "https://#{context.domains.first}/oauth2/callback")
      kubectl.apply_yaml(
        K8::AddOns::AuthProxy.new(add_on, context.endpoint, context.port, context.domains).to_yaml
      )
    end

    kubectl.apply_yaml(
      K8::AddOns::Ingress.new(add_on, context.endpoint, context.port, context.domains).to_yaml
    )
  end
end
