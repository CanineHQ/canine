class TwoFactorSetupController < ApplicationController
  skip_before_action :check_two_factor_required
  before_action :ensure_two_factor_available

  def show
    if current_user.two_factor_enabled?
      render :enabled
    else
      render :disabled
    end
  end

  def new
    current_user.generate_otp_secret! unless current_user.otp_secret.present?
    @qr_code = RQRCode::QRCode.new(current_user.otp_provisioning_uri)
  end

  def create
    if current_user.verify_otp(params[:otp_code])
      current_user.update!(otp_required_for_login: true)
      session[:otp_verified_at] = Time.current.to_s
      session[:two_factor_backup_codes] = current_user.generate_backup_codes!
      redirect_to backup_codes_two_factor_setup_path
    else
      @qr_code = RQRCode::QRCode.new(current_user.otp_provisioning_uri)
      flash.now[:alert] = "Invalid verification code. Please try again."
      render :new, status: :unprocessable_entity
    end
  end

  def backup_codes
    @backup_codes = session.delete(:two_factor_backup_codes)
    redirect_to two_factor_setup_path unless @backup_codes
  end

  def destroy
    unless current_user.verify_otp(params[:otp_code])
      redirect_to two_factor_setup_path, alert: "Invalid authenticator code."
      return
    end

    current_user.disable_two_factor!
    session.delete(:otp_verified_at)
    redirect_to two_factor_setup_path, notice: "Two-factor authentication has been disabled."
  end

  private

  def ensure_two_factor_available
    redirect_to edit_user_registration_path unless Rails.application.config.enable_2fa
  end
end
