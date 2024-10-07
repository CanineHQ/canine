class K8::Stateless::Ingress < K8::Base
  attr_accessor :service, :project, :domains, :cluster

  def initialize(service)
    @service = service
    @project = service.project
    @domains = service.domains
    @cluster = @project.cluster
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
  end
end
