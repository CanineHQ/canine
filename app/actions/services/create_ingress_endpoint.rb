class Services::CreateIngressEndpoint
  extend LightService::Action

  expects :service

  executed do |context|
    service = context.service
    next unless service.web_service?

    service.create_ingress_endpoint!(
      endpoint_name: "#{service.name}-service",
      port: 80
    )
  rescue StandardError => e
    context.fail_and_return!(e.message)
  end
end
