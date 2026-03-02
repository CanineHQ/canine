class Projects::ClusterMigrationsController < Projects::BaseController
  before_action :set_project

  def create
    target_cluster = current_account.clusters.running.find(params[:cluster_id])

    result = ClusterMigrations::MigrateProject.call(
      source_project: @project,
      target_cluster: target_cluster,
      custom_name: params[:name].presence,
      custom_namespace: params[:namespace].presence,
      managed_namespace: params[:managed_namespace] == "1"
    )

    if result.success?
      Projects::DeployLatestCommit.execute(project: result.project, current_user:)
      redirect_to project_path(result.project), notice: "Project migrated successfully"
    else
      redirect_to edit_project_path(@project), alert: result.message
    end
  end
end
