class Projects::DeploymentsController < Projects::BaseController
  before_action :set_project
  before_action :set_build, only: %i[show redeploy kill]

  def index
    @pagy, @events = pagy(@project.events.includes(eventable: [ :user, :deployment ]).order(created_at: :desc))
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
    result = Projects::DeployLatestCommit.execute(
      project: @project,
      current_user:,
      skip_build: params[:skip_build] == "true"
    )
    if result.success?
      redirect_to @project, notice: "Deploying project #{@project.name}. <a class='underline' href='#{project_deployment_path(@project, result.build)}'>Follow deployment</a>".html_safe
    else
      redirect_to @project, alert: "Failed to deploy project"
    end
  end

  def kill
    if @build.in_progress?
      @build.killed!
      @build.error("Build was killed by #{current_user.email}")
      redirect_to project_deployment_path(@project, @build), notice: "Build has been killed."
    else
      redirect_to project_deployment_path(@project, @build), alert: "Build cannot be killed (not in progress)."
    end
  end

  private

  def set_build
    @build = @project.builds.find(params[:id])
  end
end
