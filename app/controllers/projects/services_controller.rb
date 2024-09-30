class Projects::ServicesController < Projects::BaseController
  before_action :set_project
  before_action :set_service, only: %i[update destroy]

  def index
    @services = @project.project_services
  end

  def new
    @service = @project.project_services.build
  end

  def create
    service = @project.project_services.build(service_params)
    if service.save
      redirect_to project_services_path(@project), notice: "Service was successfully created."
    else
      redirect_to project_services_path(@project), alert: "Service could not be created."
    end
  end

  def update
    if @service.update(service_params)
      redirect_to project_services_path(@project), notice: "Service was successfully updated."
    else
      redirect_to project_services_path(@project), alert: "Service could not be updated."
    end
  end

  def destroy
    if @service.destroy
      redirect_to project_services_path(@project), notice: "Service was successfully destroyed."
    else
      redirect_to project_services_path(@project), alert: "Service could not be destroyed."
    end
  end

  private

  def set_service
    @service = @project.project_services.find(params[:id])
  end

  def service_params
    params.require(:project_service).permit(:service_type, :command, :name)
  end
end
