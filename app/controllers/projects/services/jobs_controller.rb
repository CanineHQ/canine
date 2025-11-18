class Projects::Services::JobsController < Projects::Services::BaseController
  before_action :set_project
  before_action :set_service

  def create
    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    job_name = "#{@service.name}-manual-#{timestamp}"
    kubectl = K8::Kubectl.new(active_connection)
    kubectl.call(
      "-n #{@project.name} create job #{job_name} --from=cronjob/#{@service.name}"
    )
    render partial: "projects/services/show", locals: { service: @service, tab: "cron-jobs" }, layout: false
  end

  def destroy
    job_name = params[:id]
    kubectl = K8::Kubectl.new(active_connection)
    kubectl.call(
      "-n #{@project.name} delete job #{job_name}"
    )

    render partial: "projects/services/show", locals: { service: @service, tab: "cron-jobs" }, layout: false
  end
end
