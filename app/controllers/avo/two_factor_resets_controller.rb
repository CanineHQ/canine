class Avo::TwoFactorResetsController < Avo::ApplicationController
  def create
    user = User.find(params[:user_id])
    user.update!(otp_required_for_login: false, otp_secret: nil, otp_backup_codes: nil)

    redirect_to avo.resources_user_path(user), flash: { success: "Two-factor authentication disabled for #{user.email}." }
  end
end
