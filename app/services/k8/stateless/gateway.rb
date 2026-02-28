class K8::Stateless::Gateway < K8::Base
  attr_accessor :service, :project, :cluster

  def initialize(service)
    @service = service
    @project = service.project
    @cluster = @project.cluster
  end

  def name
    "#{@service.name}-gateway"
  end

  def certificate_status
    return nil unless @service.domains.any?
    return nil unless @service.allow_public_networking?

    kubectl.call("get certificate #{certificate_name} -n #{@project.namespace} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'") == "True"
  end

  def certificate_name
    "#{@service.name}-tls"
  end

  def self.hostname(client)
    services = client.get_services(namespace: Clusters::Install::DEFAULT_NAMESPACE)
    service = services.find { |s| service_name(s) == "traefik" }
    raise "Traefik service not installed" if service.nil?

    h = service_hash(service)
    ingress = h.dig("status", "loadBalancer", "ingress")&.first || h.dig(:status, :loadBalancer, :ingress)&.first
    raise "Traefik load balancer address is not available yet" if ingress.nil?

    ip = ingress["ip"] || ingress[:ip]
    hostname = ingress["hostname"] || ingress[:hostname]

    if ip.present?
      { value: ip, type: :ip_address }
    else
      { value: hostname, type: :hostname }
    end
  end

  def hostname
    @hostname ||= self.class.hostname(client)
  rescue StandardError => e
    Rails.logger.error("Error getting gateway address: #{e.message}")
    nil
  end

  def self.service_hash(service)
    service.respond_to?(:to_h) ? service.to_h : service
  end

  def self.service_name(service)
    h = service_hash(service)
    h.dig("metadata", "name") || h.dig(:metadata, :name)
  end
end
