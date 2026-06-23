class TwoFactorVerificationsController < ApplicationController
  skip_before_action :authenticate_user!
  layout "homepage"

  before_action :ensure_otp_user

  def new
  end

  def create
    user = User.find(session[:otp_user_id])

    if user.validate_and_consume_otp!(params[:otp_attempt]) || user.invalidate_otp_backup_code!(params[:otp_attempt])
      session.delete(:otp_user_id)
      remember_me = session.delete(:otp_remember_me)
      user.remember_me = remember_me == "1"
      sign_in(user)
      redirect_to after_sign_in_path_for(user)
    else
      flash.now[:alert] = "Invalid code. Please try again."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def ensure_otp_user
    unless session[:otp_user_id]
      redirect_to new_user_session_path
    end
  end
end
