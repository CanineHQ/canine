class Local::OnboardingController < ApplicationController
  layout "homepage"
  skip_before_action :authenticate_user!

  def index
  end

  def account_select
    redirect_to new_user_session_path unless Rails.application.config.account_sign_in_only

    @accounts = Account.all.includes(:stack_manager)
  end

  def create
    result = Portainer::Onboarding::Create.call(params)

    if result.success?
      sign_in(result.user)
      session[:account_id] = result.account.id
      redirect_to root_path
    else
      redirect_to local_onboarding_index_path, alert: result.message
    end
  end
end
