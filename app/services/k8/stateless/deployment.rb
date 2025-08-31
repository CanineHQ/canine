class K8::Stateless::Deployment < K8::Base
  attr_accessor :service, :project, :environment_variables
  delegate :name, to: :service

  def initialize(service)
    @service = service
    @project = service.project
    @environment_variables = @project.environment_variables
  end

  def restart
    kubectl.call("rollout restart deployment/#{service.name} -n #{project.name}")
  end
end
