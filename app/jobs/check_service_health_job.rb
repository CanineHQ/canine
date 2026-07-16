class CheckServiceHealthJob < ApplicationJob
  queue_as :default

  TIMEOUT = 30.seconds

  def perform(service)
    Timeout.timeout(TIMEOUT) do
      connection = K8::Connection.new(service.project, nil, allow_anonymous: true)
      kubectl = K8::Kubectl.new(connection)

      result = kubectl.call(%w[get deployment] + [ service.name, "-n", service.project.namespace, "-o", "json" ])
      deployment = JSON.parse(result)

      desired = deployment.dig("spec", "replicas") || 1
      ready = deployment.dig("status", "readyReplicas") || 0

      service.status = ready >= desired ? :healthy : :unhealthy
      service.last_health_checked_at = DateTime.current
      service.save
    end
  rescue StandardError, Timeout::Error => e
    Rails.logger.warn("Health check failed for #{service.name}: #{e.class} - #{e.message}")
    service.update(status: :unhealthy, last_health_checked_at: DateTime.current)
  end
end
