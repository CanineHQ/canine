class Accounts::Teams::TeamResourcesController < ApplicationController
  before_action :set_team

  def create
    resourceable = find_resourceable(team_resource_params[:resourceable_type], team_resource_params[:resourceable_id])
    @team_resource = @team.team_resources.new(resourceable: resourceable)

    if @team_resource.save
      redirect_to team_path(@team), notice: "Resource access was successfully granted."
    else
      redirect_to team_path(@team), alert: "Failed to grant resource access."
    end
  end

  def destroy
    @team_resource = @team.team_resources.find(params[:id])
    @team_resource.destroy

    redirect_to team_path(@team), notice: "Resource access was successfully revoked."
  end

  private

  def set_team
    @team = current_account.teams.friendly.find(params[:team_id])
  end

  def team_resource_params
    params.permit(:resourceable_type, :resourceable_id)
  end

  def find_resourceable(type, id)
    case type
    when "Cluster"
      current_account.clusters.find(id)
    when "Project"
      current_account.projects.find(id)
    when "AddOn"
      current_account.add_ons.find(id)
    else
      raise "Invalid resourceable type"
    end
  end
end
