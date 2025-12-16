class Accounts::Teams::TeamMembersSearchController < ApplicationController
  before_action :set_team

  def index
    query = params[:q].to_s.strip

    # Get users in the account who are NOT already in this team
    users = if query.present?
              current_account.users
                             .where.not(id: @team.users.pluck(:id))
                             .where("email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?",
                                    "%#{query}%", "%#{query}%", "%#{query}%")
                             .limit(10)
    else
              []
    end

    render json: users.map { |user|
      {
        id: user.id,
        email: user.email,
        name: user.name,
        first_name: user.first_name,
        last_name: user.last_name,
        avatar_url: helpers.avatar_path(user, size: 64)
      }
    }
  end

  private

  def set_team
    @team = current_account.teams.friendly.find(params[:team_id])
  end
end
