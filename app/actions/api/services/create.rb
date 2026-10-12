# frozen_string_literal: true

# Adds a service (web, background worker, or cron job) to a project. Takes effect on the next deploy.
# params: name, service_type, container_port, replicas, command, healthcheck_url,
#         allow_public_networking, cron_schedule
module Api
  module Services
    class Create
      extend LightService::Action
      expects :project, :params
      promises :service

      executed do |context|
        params = context.params.to_h.with_indifferent_access

        service_params = ActionController::Parameters.new(
          service: {
            name: params[:name],
            service_type: params[:service_type],
            container_port: params[:container_port] || 3000,
            replicas: params[:replicas] || 1,
            command: params[:command],
            healthcheck_url: params[:healthcheck_url],
            allow_public_networking: params[:allow_public_networking] || false
          }
        )
        service_params[:service][:cron_schedule] = { schedule: params[:cron_schedule] } if params[:cron_schedule].present?

        service = context.project.services.build(Service.permitted_params(service_params))
        context.service = service
        result = ::Services::Create.call(service, service_params)

        if result.failure?
          context.fail_and_return!(service.errors.full_messages.to_sentence.presence || result.message)
        end
      end
    end
  end
end
