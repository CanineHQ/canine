class PasswordChangeController < ApplicationController
  layout "homepage"
  skip_before_action :check_password_change_required

  def show
    unless current_user.password_change_required?
      redirect_to root_path
    end
  end

  def update
    if current_user.update_with_password(password_params.merge(password_change_required: false))
      bypass_sign_in(current_user)
      redirect_to root_path, notice: "Password changed successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
