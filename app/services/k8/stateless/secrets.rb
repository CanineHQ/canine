class K8::Stateless::Secrets < K8::Base
  attr_reader :project
  delegate :name, to: :project

  def initialize(project)
    @project = project
  end
end
