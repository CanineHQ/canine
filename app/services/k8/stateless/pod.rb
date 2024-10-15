class K8::Stateless::Pod < K8::Base
  attr_accessor :project, :id, :name

  def initialize(project)
    @project = project
    @id = SecureRandom.uuid[0..7]
  end

  def name
    "#{project.name}-run-#{id}"
  end
end
