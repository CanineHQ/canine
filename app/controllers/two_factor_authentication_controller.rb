class TwoFactorAuthenticationController < ApplicationController
  before_action :authenticate_user!

  def create
    current_user.otp_secret = User.generate_otp_secret
    current_user.save!
    @qr_svg = current_user.two_factor_qr_code_svg
    render layout: false
  end

  def confirm
    if current_user.validate_and_consume_otp!(params[:otp_attempt])
      @recovery_codes = current_user.generate_otp_backup_codes!
      current_user.update!(otp_required_for_login: true)
    else
      @qr_svg = current_user.two_factor_qr_code_svg
      flash.now[:alert] = "Invalid code. Please try again."
      render :create, layout: false
    end
  end

  def destroy
    if current_user.validate_and_consume_otp!(params[:otp_attempt])
      current_user.update!(otp_required_for_login: false, otp_secret: nil, otp_backup_codes: nil)
      redirect_to edit_user_registration_path, notice: "Two-factor authentication disabled."
    else
      redirect_to edit_user_registration_path, alert: "Invalid code. Two-factor authentication was not disabled."
    end
  end
end
