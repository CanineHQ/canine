class K8::Namespace < K8::Base
  attr_accessor :project

  def initialize(project)
    @project = project
  end
end
