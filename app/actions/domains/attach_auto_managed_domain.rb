class Domains::AttachAutoManagedDomain
  extend LightService::Action

  expects :service

  executed do |context|
    next unless Dns::AutoSetupService.enabled?

    service = context.service
    next unless service.allow_public_networking?
    next unless service.web_service?
    next unless service.ingress_endpoint
    next if service.ingress_endpoint.domains.exists?(auto_managed: true)

    domain_name = "#{service.name}-#{service.project.slug}.oncanine.run"

    service.ingress_endpoint.domains.create!(
      domain_name: domain_name,
      auto_managed: true
    )
  rescue StandardError => e
    context.fail_and_return!(e.message)
  end
end
