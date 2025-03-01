class Scheduled::CheckHealthJob < ApplicationJob
  queue_as :default

  def perform
    Service.web_service.where('healthcheck_url IS NOT NULL').each do |service|
      # url = File.join("http://#{service.name}-service.#{service.project.name}.svc.cluster.local", service.healthcheck_url)
      # K8::Client.from_project(service.project).run_command("curl -s -o /dev/null -w '%{http_code}' #{url}")
      if service.domains.any?
        url = File.join("https://#{service.domains.first.domain_name}", service.healthcheck_url)
        Rails.logger.info("Checking health for #{service.name} at #{url}")
        response = HTTParty.get(url)
        if response.success?
          service.status = :healthy
        else
          service.status = :unhealthy
        end
        service.last_health_checked_at = DateTime.current
        service.save
      end
    end
  end
end

