class AddOns::ForksController < ApplicationController
  before_action :set_add_on

  def create
    result = ClusterMigrations::MigrateAddOn.execute(
      source_add_on: @add_on,
      target_cluster: @add_on.cluster,
      custom_name: params[:name].presence,
      custom_namespace: params[:namespace].presence,
      managed_namespace: params[:managed_namespace] == "1"
    )

    if result.success?
      AddOns::ForkJob.perform_later(
        @add_on,
        result.migrated_add_on,
        current_user,
      )
      redirect_to add_on_path(result.migrated_add_on), notice: "Forking database from #{@add_on.name}..."
    else
      redirect_to add_on_path(@add_on), alert: result.message
    end
  end

  private

  def set_add_on
    @add_on = current_account.add_ons.find(params[:add_on_id])
  end
end
