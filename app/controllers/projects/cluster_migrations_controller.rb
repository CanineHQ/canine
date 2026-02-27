class Projects::ClusterMigrationsController < Projects::BaseController
  before_action :set_project

  def new
    @clusters = current_account.clusters.running.where.not(id: @project.cluster_id)
  end

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
      redirect_to new_project_cluster_migration_path(@project), alert: result.message
    end
  end
end
