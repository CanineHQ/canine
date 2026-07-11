class Scheduled::CheckHealthJob < ApplicationJob
  queue_as :default

  def perform
    Service.where.not(status: :pending).where.not(service_type: :cron_job).each do |service|
      check_service_health(service)
    end
  end

  private

  def check_service_health(service)
    connection = K8::Connection.new(service.project, nil, allow_anonymous: true)
    kubectl = K8::Kubectl.new(connection)

    result = kubectl.call(%w[get deployment] + [ service.name, "-n", service.project.namespace, "-o", "json" ])
    deployment = JSON.parse(result)

    desired = deployment.dig("spec", "replicas") || 1
    ready = deployment.dig("status", "readyReplicas") || 0

    service.status = ready >= desired ? :healthy : :unhealthy
    service.last_health_checked_at = DateTime.current
    service.save
  rescue StandardError => e
    Rails.logger.warn("Health check failed for #{service.name}: #{e.class} - #{e.message}")
    service.update(status: :unhealthy, last_health_checked_at: DateTime.current)
  end
end
