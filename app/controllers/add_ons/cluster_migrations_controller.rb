class AddOns::ClusterMigrationsController < ApplicationController
  before_action :set_add_on

  def create
    target_cluster = current_account.clusters.running.find(params[:cluster_id])

    result = ClusterMigrations::MigrateAddOn.execute(
      source_add_on: @add_on,
      target_cluster: target_cluster,
      custom_name: params[:name].presence,
      custom_namespace: params[:namespace].presence,
      managed_namespace: params[:managed_namespace] == "1"
    )

    if result.success?
      AddOns::InstallJob.perform_later(result.migrated_add_on, current_user)
      redirect_to add_on_path(result.migrated_add_on), notice: "Add-on migrated successfully"
    else
      redirect_to edit_add_on_path(@add_on), alert: result.message
    end
  end

  private

  def set_add_on
    @add_on = current_account.add_ons.find(params[:add_on_id])
  end
end
