class Accounts::Teams::TeamMembershipsController < ApplicationController
  before_action :set_team

  def create
    user = User.find(team_membership_params[:user_id])
    @team_membership = @team.team_memberships.new(user: user)

    if @team_membership.save
      redirect_to team_path(@team), notice: "Member was successfully added to team."
    else
      redirect_to team_path(@team), alert: "Failed to add member to team."
    end
  end

  def destroy
    @team_membership = @team.team_memberships.find(params[:id])
    @team_membership.destroy

    redirect_to team_path(@team), notice: "Member was successfully removed from team."
  end

  private

  def set_team
    @team = current_account.teams.friendly.find(params[:team_id])
  end

  def team_membership_params
    params.permit(:user_id)
  end
end
