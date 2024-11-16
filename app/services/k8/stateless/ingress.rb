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

  def certificate_status
    return nil unless @service.domains.any?
    return nil unless @service.allow_public_networking?
    return nil unless @service.allow_public_networking?

    K8::Kubectl.new(@cluster.kubeconfig).call("get certificate example-tls -n #{@project.name} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'") == "True"
  end

  def get_ingress
    result = K8::Kubectl.new(@cluster.kubeconfig).call('get ingresses -o yaml')
    results = YAML.safe_load(result)
    results['items'].find { |r| r['metadata']['name'] == "#{@service.project.name}-ingress" }
  end

  def ip_address
    @ip_address ||= begin
      service = client.get_services.find { |s| s['metadata']['name'] == 'ingress-nginx-controller' }
      service.status.loadBalancer.ingress[0].ip
    end
  rescue StandardError => e
    Rails.logger.error("Error getting ingress ip address: #{e.message}")
    nil
  end
end
