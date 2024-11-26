class Projects::Services::JobsController < Projects::Services::BaseController
  before_action :set_project
  before_action :set_service

  def create
    K8::Kubectl.from_project(@project).call("-n #{@project.name} create job --from=cronjob/#{@service.name}")

    redirect_to project_services_path(@project), notice: "Job #{@service.name} created."
  end
end
