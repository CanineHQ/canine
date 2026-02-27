class AddOns::ClusterMigrationsController < ApplicationController
  before_action :set_add_on

  def new
    @clusters = current_account.clusters.running.where.not(id: @add_on.cluster_id)
  end

  def create
    target_cluster = current_account.clusters.running.find(params[:cluster_id])

    result = ClusterMigrations::MigrateAddOn.execute(
      source_add_on: @add_on,
      target_cluster: target_cluster
    )

    if result.success?
      AddOns::InstallJob.perform_later(result.migrated_add_on, current_user)
      redirect_to add_on_path(result.migrated_add_on), notice: "Add-on migrated successfully"
    else
      redirect_to new_add_on_cluster_migration_path(@add_on), alert: result.message
    end
  end

  private

  def set_add_on
    @add_on = current_account.add_ons.find(params[:add_on_id])
  end
end
