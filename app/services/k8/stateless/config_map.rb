class K8::Stateless::ConfigMap < K8::Base
  attr_reader :project
  delegate :name, to: :project

  def initialize(project)
    @project = project
  end
end
