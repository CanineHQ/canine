class Local::OnboardingController < ApplicationController
  before_action :authorize
  layout "onboarding"
  def index
  end

  private

  def authorize
    unless Flipper.enabled?(:portainer_oauth)
      flash[:error] = "This feature is not yet ready"
      redirect_to root_path
    end
  end
end
