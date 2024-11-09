class Local::PagesController < ApplicationController
  skip_before_action :set_github_token_if_not_exists

  def github_token
  end

  def update_github_token
    client = Octokit::Client.new(access_token: params[:github_token])
    provider = current_user.providers.find_or_initialize_by(provider: "github")
    provider.update!(access_token: params[:github_token])
    username = client.user[:login]
    provider.auth = {
      info: {
        nickname: username
      }
    }.to_json
    provider.save!
    flash[:notice] = "Your Github account (#{username}) has been connected"
    redirect_to root_path
  rescue Octokit::Unauthorized
    flash[:error] = "Invalid personal access token"
    redirect_to github_token_path
  end
end
