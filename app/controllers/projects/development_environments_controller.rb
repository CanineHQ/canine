class Projects::DevelopmentEnvironmentsController < Projects::BaseController
  before_action :ensure_dev_environments_enabled

  def index
    @development_environment_configuration = @project.development_environment_configuration
    @dev_environment_forks = @project.dev_environment_forks.includes(:child_project)
  end

  def create
    result = ProjectForks::CreateDevEnvironment.call(parent_project: @project)

    if result.success?
      Projects::DeployLatestCommit.execute(project: result.project, current_user:)
      redirect_to project_path(result.project), notice: "Development environment created"
    else
      redirect_to project_development_environments_path(@project), alert: "Failed to create development environment: #{result.message}"
    end
  end

  private

  def ensure_dev_environments_enabled
    unless @project.development_environment_enabled?
      redirect_to edit_project_path(@project), alert: "Development environments are not enabled for this project."
    end
  end
end
