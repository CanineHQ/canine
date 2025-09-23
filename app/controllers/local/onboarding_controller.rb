class Local::OnboardingController < ApplicationController
  layout "homepage"
  skip_before_action :authenticate_user!

  def index
  end

  def create
    result = Portainer::Onboarding::Create.call(params)

    if result.success?
      sign_in(result.user)
      redirect_to root_path
    else
      redirect_to local_onboarding_index_path, alert: result.message
    end
  end
end
