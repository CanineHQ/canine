class Local::PortainersController < ApplicationController
  before_action :authorize

  def show
  end

  def update
    stack_manager = current_account.stack_manager || current_account.build_stack_manager
    stack_manager.update!(provider_url: params[:provider_url])
    authenticate(auth_code: params[:password], username: params[:username])
    redirect_to root_path
  end

  def github_oauth
    authenticate(auth_code: params[:code])
    redirect_to root_path
  end

  private

  def authenticate(auth_code:, username: nil)
    return if auth_code.blank?

    result = Portainer::Authenticate.execute(
      stack_manager: current_account.stack_manager,
      user: current_user,
      auth_code:,
      username:
    )

    if result.success?
      flash[:notice] = "The Portainer configuration has been updated"
    else
      flash[:error] = result.message
    end
  end

  def authorize
    unless Flipper.enabled?(:portainer_oauth)
      flash[:error] = "This feature is not yet ready"
      redirect_to root_path
    end
  end
end
