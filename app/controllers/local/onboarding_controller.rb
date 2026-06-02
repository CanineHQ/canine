class Local::OnboardingController < ApplicationController
  layout "homepage"
  skip_before_action :authenticate_user!

  def index
    redirect_to account_select_local_onboarding_index_path if Rails.application.config.account_sign_in_only
    redirect_to portainer_local_onboarding_index_path if portainer_only?
  end

  def account_select
    redirect_to new_user_session_path unless Rails.application.config.account_sign_in_only

    @accounts = Account.all.includes(:stack_manager)
  end

  def portainer
    redirect_to local_onboarding_index_path unless portainer_enabled?
  end

  def create
    result = Portainer::Onboarding::Create.call(params)

    if result.success?
      sign_in(result.user)
      session[:account_id] = result.account.id
      redirect_to root_path
    else
      redirect_to portainer_local_onboarding_index_path, alert: result.message
    end
  end

  private

  def onboarding_method
    Rails.application.config.onboarding_method
  end

  def portainer_enabled?
    onboarding_method == "portainer"
  end

  def portainer_only?
    portainer_enabled?
  end
end
