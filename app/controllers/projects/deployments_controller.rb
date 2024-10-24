class Projects::DeploymentsController < Projects::BaseController
  before_action :set_project
  before_action :set_build, only: %i[show redeploy]

  def index
    @pagy, @builds = pagy(@project.builds.order(created_at: :desc))
  end

  def show; end

  def redeploy
    new_build = @build.dup.tap do |build|
      build.status = :in_progress
      build.current_user = current_user
    end
    if new_build.save
      Projects::BuildJob.perform_later(new_build)
      redirect_to root_projects_path(@project, new_build), notice: "Redeploying..."
    else
      redirect_to root_projects_path(@project), alert: "Failed to redeploy"
    end
  end

  def deploy
    result = Projects::DeployLatestCommit.execute(project: @project, current_user:)
    if result.success?
      redirect_to @project, notice: "Deploying project..."
    else
      redirect_to @project, alert: "Failed to deploy project"
    end
  end

  private

  def set_build
    @build = @project.builds.find(params[:id])
  end
end
