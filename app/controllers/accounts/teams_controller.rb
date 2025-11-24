class Accounts::TeamsController < ApplicationController
  include SettingsHelper
  before_action :set_team, only: %i[show edit update destroy]

  def index
    @pagy, @teams = pagy(current_account.teams)
  end

  def show
    @pagy, @team_memberships = pagy(@team.team_memberships)
  end

  def new
    @team = current_account.teams.new
  end

  def create
    @team = current_account.teams.new(team_params)

    if @team.save
      redirect_to teams_path, notice: "Team was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @team.update(team_params)
      redirect_to team_path(@team), notice: "Team was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @team.destroy

    redirect_to teams_path, notice: "Team was successfully destroyed."
  end

  private

  def set_team
    @team = current_account.teams.friendly.find(params[:id])
  end

  def team_params
    params.require(:team).permit(:name)
  end
end
