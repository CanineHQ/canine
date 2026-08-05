class EmailPreferencesController < ApplicationController
  def show
    @preference = current_user.email_preference || current_user.build_email_preference
  end

  def update
    preference = current_user.email_preference || current_user.build_email_preference
    preference.update(email_preference_params)
    redirect_to email_preference_path, notice: "Email preferences updated."
  end

  private

  def email_preference_params
    params.require(:email_preference).permit(:service_health)
  end
end
