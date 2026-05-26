class Scheduled::CheckHealthJob < ApplicationJob
  queue_as :default

  def perform
    Service.web_service.where('healthcheck_url IS NOT NULL').each do |service|
      # url = File.join("http://#{service.name}-service.#{service.project.namespace}.svc.cluster.local", service.healthcheck_url)
      # K8::Client.from_project(service.project).run_command("curl -s -o /dev/null -w '%{http_code}' #{url}")
      if service.domains.any?
        url = File.join("https://#{service.domains.first.domain_name}", service.healthcheck_url)
        Rails.logger.info("Checking health for #{service.name} at #{url}")
        previous_status = service.status
        begin
          response = HTTParty.get(url, timeout: 10)
          if response.success?
            service.status = :healthy
          else
            service.status = :unhealthy
          end
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, HTTParty::Error, OpenSSL::SSL::SSLError => e
          Rails.logger.warn("Health check failed for #{service.name}: #{e.class} - #{e.message}")
          service.status = :unhealthy
        end
        service.last_health_checked_at = DateTime.current
        service.save

        notify_unhealthy(service, url) if previous_status == "healthy" && service.status == "unhealthy"
      end
    end
  end

  private

  def notify_unhealthy(service, url)
    project = service.project
    recipients = project.account.users.pluck(:email).compact.uniq
    return if recipients.empty?

    link = Rails.application.routes.url_helpers.project_url(project)

    recipients.each do |email|
      NotificationMailer.notify(
        to: email,
        title: "#{project.name}/#{service.name} is unhealthy",
        text: "The healthcheck at #{url} failed. The service has transitioned from healthy to unhealthy.",
        link: link,
        link_text: "View project"
      ).deliver_later
    end
  end
end
