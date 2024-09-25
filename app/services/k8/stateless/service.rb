class K8::Stateless::Service < K8::Base
  FILE_PATH = Rails.root.join('path', 'to', 'file.yaml.erb')
  attr_accessor :project, :name, :target_port

  def initialize(project)
    @project = project
    @name = project.name
    @target_port = 3000
  end
end
