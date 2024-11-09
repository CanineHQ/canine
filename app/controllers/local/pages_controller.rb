class Local::PagesController < ApplicationController
  EXPECTED_SCOPES = ["repo", "write:packages"]
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
    # Check per
    provider.save!
    if (client.scopes & EXPECTED_SCOPES).sort != EXPECTED_SCOPES.sort
      flash[:error] = "Invalid scopes. Please check that your personal access token has the following scopes: #{EXPECTED_SCOPES.join(", ")}"
      redirect_to github_token_path
    else
      flash[:notice] = "Your Github account (#{username}) has been connected"
      redirect_to root_path
    end
  rescue Octokit::Unauthorized
    flash[:error] = "Invalid personal access token"
    redirect_to github_token_path
  end
end
