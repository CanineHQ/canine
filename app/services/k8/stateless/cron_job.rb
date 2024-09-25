class K8::Stateless::CronJob
  attr_accessor :service
  def initialize(service)
    @service = service
  end
end