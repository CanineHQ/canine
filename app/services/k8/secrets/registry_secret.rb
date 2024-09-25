class K8::Secrets::RegistrySecret < K8::Base
  attr_accessor :name, :docker_config_json

  def initialize(project, docker_config_json)
    @project = project
    @name = project.name
    @docker_config_json = docker_config_json
  end
end
