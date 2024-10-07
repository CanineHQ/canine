class K8::Stateless::CronJob
  attr_accessor :service, :project
  def initialize(service)
    @service = service
    @project = service.project
  end
end