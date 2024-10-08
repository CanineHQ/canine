class K8::Stateless::CronJob < K8::Base
  attr_accessor :service, :project
  def initialize(service)
    @service = service
    @project = service.project
  end

  def restart
    K8::Kubectl.from_project(project).call("rollout restart cronjob/#{service.name}")
  end
end