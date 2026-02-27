class Projects::ClusterMigrationsController < Projects::BaseController
  before_action :set_project

  def create
    target_cluster = current_account.clusters.running.find(params[:cluster_id])

    result = ClusterMigrations::MigrateProject.execute(
      source_project: @project,
      target_cluster: target_cluster
    )

    if result.success?
      Projects::DeployLatestCommit.execute(project: result.migrated_project, current_user:)
      redirect_to project_path(result.migrated_project), notice: "Project migrated successfully"
    else
      redirect_to edit_project_path(@project), alert: result.message
    end
  end
end
