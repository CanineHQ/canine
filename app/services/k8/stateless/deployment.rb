class K8::Stateless::Deployment < K8::Base
  attr_accessor :service, :project, :environment_variables
  delegate :name, to: :service

  def initialize(service, user)
    @service = service
    @project = service.project
    @environment_variables = @project.environment_variables
    super(user)
  end

  def restart
    K8::Kubectl.new(K8::Connection.new(project.cluster, user)).call("rollout restart deployment/#{service.name} -n #{project.name}")
  end
end
