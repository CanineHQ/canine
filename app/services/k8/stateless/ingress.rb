class K8::Stateless::Ingress < K8::Base
  attr_accessor :service, :project, :domains

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
end
