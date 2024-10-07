class Projects::ServicesController < Projects::BaseController
  before_action :set_project
  before_action :set_service, only: %i[update destroy]

  def index
    @services = @project.services
  end

  def new
    @service = @project.services.build
  end

  def create
    result = Services::Create.call(@project.services.build(service_params), params)
    redirect(success: result.success?, type: "created")
  end

  def update
    redirect(success: @service.update(service_params), type: "updated")
  end

  def destroy
    redirect(success: @service.destroy, type: "destroyed")
  end

  private

  def redirect(success:, type:)
   if success
      redirect_to project_services_path(@project), notice: "Service was successfully #{type}."
   else
      redirect_to project_services_path(@project), alert: "Service could not be #{type}."
   end
  end

  def set_service
    @service = @project.services.find(params[:id])
  end

  def service_params
    params.require(:service).permit(
      :service_type,
      :command,
      :name,
      :container_port,
    )
  end
end
