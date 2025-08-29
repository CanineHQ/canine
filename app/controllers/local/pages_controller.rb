class Local::PagesController < ApplicationController
  EXPECTED_SCOPES = [ "repo", "write:packages" ]
  if Rails.application.config.local_mode
    skip_before_action :set_github_token_if_not_exists
  end

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

  def portainer_configuration
  end

  def update_portainer_configuration
    stack_manager = current_account.stack_manager || current_account.build_stack_manager
    stack_manager.update!(provider_url: params[:provider_url])
    result = Portainer::Authenticate.execute(stack_manager:, user: current_user, auth_code: params[:password], username: params[:username])
    if result.success?
      flash[:notice] = "The Portainer configuration has been updated"
    else
      flash[:error] = result.message
    end
    redirect_to root_path
  end

  def github_oauth
    result = Portainer::Authenticate.execute(
      stack_manager: current_account.stack_manager,
      user: current_user,
      auth_code: params[:code]
    )
    if result.success?
      flash[:notice] = "The Portainer configuration has been updated"
    else
      flash[:error] = result.message
    end
    redirect_to root_path
  end
end
