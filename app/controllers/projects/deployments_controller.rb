class Projects::DeploymentsController < Projects::BaseController
  before_action :set_project
  before_action :set_build, only: %i[show redeploy]

  def index
    @pagy, @builds = pagy(@project.builds.sort_by_params(params[:sort], 'desc'))
  end

  def show; end

  def redeploy
    new_build = @build.dup
    if new_build.save
      Projects::BuildJob.perform_later(new_build)
      redirect_to project_deployment_path(@project, new_build), notice: 'Redeploying...'
    else
      redirect_to project_deployments_url(@project), alert: 'Failed to redeploy'
    end
  end

  def deploy
    result = Projects::DeployLatestCommit.execute(project: @project)
    if result.success?
      redirect_to @project, notice: 'Deploying project...'
    else
      redirect_to @project, alert: 'Failed to deploy project'
    end
  end

  private

  def set_build
    @build = @project.builds.find(params[:id])
  end
end
