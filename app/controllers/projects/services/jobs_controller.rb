class Projects::Services::JobsController < Projects::Services::BaseController
  before_action :set_project
  before_action :set_service

  def create
    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    job_name = "#{@service.name}-manual-#{timestamp}"
    kubectl = K8::Kubectl.new(K8::Connection.new(@project.cluster, current_user))
    kubectl.call(
      "-n #{@project.name} create job #{job_name} --from=cronjob/#{@service.name}"
    )

    redirect_to project_services_path(@project), notice: "Job #{job_name} created."
  end
end
