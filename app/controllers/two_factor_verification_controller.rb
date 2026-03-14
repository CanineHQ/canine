class TwoFactorVerificationController < ApplicationController
  layout "homepage"
  skip_before_action :check_two_factor_required

  def show
    unless Rails.application.config.enable_2fa && current_user.two_factor_enabled?
      redirect_to root_path
    end
  end

  def create
    if current_user.verify_otp(params[:otp_code])
      session[:otp_verified_at] = Time.current.to_s
      redirect_to root_path, notice: "Two-factor authentication verified."
    else
      flash.now[:alert] = "Invalid verification code. Please try again."
      render :show, status: :unprocessable_entity
    end
  end
end
