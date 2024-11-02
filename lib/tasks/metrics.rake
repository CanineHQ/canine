namespace :metrics do
  desc "Query healthchecks" do
  end
  task check_health: :environment do
    Service.web_service.where('healthcheck_url IS NOT NULL').each do |service|
      #url = File.join("http://#{service.name}-service.#{service.project.name}.svc.cluster.local", service.healthcheck_url)
      #K8::Client.from_project(service.project).run_command("curl -s -o /dev/null -w '%{http_code}' #{url}")
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

  desc "Poll Kubernetes cluster metrics"
  task nodes: :environment do
    Cluster.running.each do |cluster|
      nodes = K8::Metrics::Metrics.call(cluster)
    end
  end

  desc "flush metrics"
  task flush: :environment do |_, args|
    Metric.where("created_at < ?", 1.days.ago).destroy_all
  end
end
