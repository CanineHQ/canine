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

    kubectl.call(%w[get certificate] + [ certificate_name, "-n", @project.namespace, "-o", 'jsonpath={.status.conditions[?(@.type=="Ready")].status}' ]) == "True"
  end

  def certificate_name
    "#{@service.name}-tls"
  end

  def get_ingress
    result = kubectl.call(%w[get ingresses -o yaml])
    results = YAML.safe_load(result)
    results['items'].find { |r| r['metadata']['name'] == "#{@service.project.namespace}-ingress" }
  end

  INGRESS_APP_LABELS = %w[traefik ingress-nginx].freeze

  def self.hostname(client)
    services = client.get_services(namespace: nil).select { |s| s.spec.type == "LoadBalancer" }
    service = INGRESS_APP_LABELS.lazy.filter_map { |label|
      services.find { |s| s.metadata.labels&.[]("app.kubernetes.io/name") == label }
    }.first

    if service.nil?
      raise "No ingress controller service found"
    end
    ingress = service.status&.loadBalancer&.ingress&.first
    if ingress.nil?
      raise "No ingress found for ingress controller"
    end

    if ingress.ip
      {
        value: ingress.ip,
        type: :ip_address
      }
    else
      {
        value: ingress.hostname,
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
