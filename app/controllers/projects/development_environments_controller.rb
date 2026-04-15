class Projects::DevelopmentEnvironmentsController < Projects::BaseController
  def index
    @development_environment_configuration = @project.development_environment_configuration

    unless @project.development_environment_enabled?
      redirect_to edit_project_path(@project), alert: "Development environments are not enabled for this project."
    end
  end
end
