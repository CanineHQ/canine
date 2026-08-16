class CheckServiceHealthJob < ApplicationJob
  queue_as :monitoring

  TIMEOUT = 10.seconds

  def perform(service)
    previous_status = service.status

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

    notify_status_change(service, previous_status)
  rescue StandardError, Timeout::Error => e
    Rails.logger.warn("Health check failed for #{service.name}: #{e.class} - #{e.message}")
    previous_status = service.status
    service.update(status: :unhealthy, last_health_checked_at: DateTime.current)
    notify_status_change(service, previous_status)
  end

  private

  def notify_status_change(service, previous_status)
    return if service.status == previous_status

    went_down = service.unhealthy? && previous_status != "unhealthy"
    came_back = service.healthy? && previous_status == "unhealthy"

    return unless went_down || came_back

    project = service.project
    status_change = went_down ? :down : :restored

    ServiceHealthNotifier.with(project: project, service: service, status_change: status_change).deliver_later
  end
end
