class K8::Stateless::Ingress < K8::Base
  attr_accessor :service, :project, :domains, :cluster

  def initialize(service)
    @service = service
    @project = service.project
    @cluster = @project.cluster
  end

  def name
    "#{@service.name}-ingress"
  end

  def ingress_class_name
    if @cluster.cluster_packages.exists?(name: "traefik-ingress")
      "traefik"
    else
      "nginx"
    end
  end

  def certificate_status
    return nil unless @service.domains.any?
    return nil unless @service.allow_public_networking?

    kubectl.call("get certificate #{certificate_name} -n #{@project.namespace} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'") == "True"
  end

  def certificate_name
    "#{@service.name}-tls"
  end

  def get_ingress
    result = kubectl.call('get ingresses -o yaml')
    results = YAML.safe_load(result)
    results['items'].find { |r| r['metadata']['name'] == "#{@service.project.namespace}-ingress" }
  end

  INGRESS_SERVICE_NAMES = %w[traefik ingress-nginx-controller].freeze

  def self.hostname(client)
    services = client.get_services
    service = INGRESS_SERVICE_NAMES.lazy.filter_map { |name| services.find { |s| s['metadata']['name'] == name } }.first

    if service.nil?
      raise "No ingress controller service found"
    end
    if service.status.loadBalancer.ingress[0].ip
      {
        value: service.status.loadBalancer.ingress[0].ip,
        type: :ip_address
      }
    else
      {
        value: service.status.loadBalancer.ingress[0].hostname,
        type: :hostname
      }
    end
  end

  def hostname
    @hostname ||= begin
      self.class.hostname(self.client)
    end
  rescue StandardError => e
    Rails.logger.error("Error getting ingress ip address: #{e.message}")
    nil
  end
end
