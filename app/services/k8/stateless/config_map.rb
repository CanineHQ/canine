class K8::Stateless::ConfigMap < K8::Base
  attr_reader :project

  def initialize(project)
    @project = project
  end
end
