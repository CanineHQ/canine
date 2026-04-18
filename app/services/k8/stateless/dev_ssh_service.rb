class K8::Stateless::DevSshService < K8::Base
  attr_accessor :project, :service, :dev_env

  def initialize(service)
    @service = service
    @project = service.project
    @dev_env = @project.development_environment_configuration
  end

  def name
    "#{service.name}-dev-ssh"
  end

  def enabled?
    dev_env&.enabled? && dev_env.branch_name == project.branch
  end
end
