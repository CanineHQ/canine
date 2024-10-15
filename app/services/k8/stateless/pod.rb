class K8::Stateless::Pod < K8::Base
  attr_accessor :project, :id

  def initialize(project)
    @project = project
    @id = SecureRandom.uuid[0..7]
  end
end
