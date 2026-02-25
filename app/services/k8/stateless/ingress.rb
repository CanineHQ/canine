class K8::Stateless::Ingress < K8::Base
  attr_accessor :service, :project, :domains, :cluster

  def initialize(service)
    @service = service
    @project = service.project
    @cluster = @project.cluster
  end

  def name
    gateway.name
  end

  def certificate_status
    gateway.connect(connection).certificate_status
  end

  def certificate_name
    gateway.certificate_name
  end

  def self.hostname(client)
    K8::Stateless::Gateway.hostname(client)
  end

  def hostname
    @hostname ||= begin
      self.class.hostname(self.client)
    end
  rescue StandardError => e
    Rails.logger.error("Error getting gateway address: #{e.message}")
    nil
  end

  def to_yaml
    [ gateway.to_yaml, http_route.to_yaml, certificate.to_yaml ].join("\n---\n")
  end

  private

  def gateway
    @gateway ||= K8::Stateless::Gateway.new(service)
  end

  def http_route
    @http_route ||= K8::Stateless::Httproute.new(service)
  end

  def certificate
    @certificate ||= K8::Stateless::Certificate.new(service)
  end
end
