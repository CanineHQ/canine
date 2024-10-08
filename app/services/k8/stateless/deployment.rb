class K8::Stateless::Deployment < K8::Base
  attr_accessor :service, :project, :environment_variables

  def initialize(service)
    @service = service
    @project = service.project
    @environment_variables = @project.environment_variables
  end

  def restart
    K8::Kubectl.from_project(project).call("rollout restart deployment/#{service.name}")
  end
end
