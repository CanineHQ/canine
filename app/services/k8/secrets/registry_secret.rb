class K8::Secrets::RegistrySecret < K8::Base
  attr_accessor :project, :docker_config_json

  def initialize(project, docker_config_json)
    @project = project
    @docker_config_json = docker_config_json
  end
end
