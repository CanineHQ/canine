class Domains::AttachAutoManagedDomain
  extend LightService::Action

  expects :service

  executed do |context|
    next unless Dns::AutoSetupService.enabled?

    service = context.service
    next unless service.allow_public_networking?
    next unless service.web_service?
    next if service.domains.exists?(auto_managed: true)

    project = service.project
    public_web_services = project.services.web_service.where(allow_public_networking: true)
    domain_name = if public_web_services.count <= 1
      "#{project.slug}.oncanine.run"
    else
      "#{service.name}-#{project.slug}.oncanine.run"
    end

    service.domains.create!(
      domain_name: domain_name,
      auto_managed: true
    )
  rescue StandardError => e
    context.fail_and_return!(e.message)
  end
end
