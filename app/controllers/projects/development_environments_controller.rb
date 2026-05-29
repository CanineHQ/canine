class Projects::DevelopmentEnvironmentsController < Projects::BaseController
  before_action :ensure_development_environments_enabled

  def index
    @development_environment_configuration = @project.development_environment_configuration
    @development_environments = @project.development_environments.includes(:child_project)
    @git_providers = current_user.providers.where(provider: @project.provider.provider).ordered
  end

  def create
    git_provider = current_user.providers.find(params[:git_provider_id])
    result = ProjectForks::CreateDevelopmentEnvironment.call(parent_project: @project, current_user:, git_provider:)

    if result.success?
      Projects::DeployLatestCommit.execute(project: result.project, current_user:)
      redirect_to project_path(result.project), notice: "Development environment created"
    else
      redirect_to project_development_environments_path(@project), alert: "Failed to create development environment: #{result.message}"
    end
  end

  private

  def ensure_development_environments_enabled
    unless @project.development_environment_enabled?
      redirect_to edit_project_path(@project), alert: "Development environments are not enabled for this project."
    end
  end
end
