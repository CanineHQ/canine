class Accounts::AccountUsersController < ApplicationController
  include SettingsHelper
  def create
    user = User.find_or_initialize_by(email: user_params[:email]) do |user|
      user.first_name = user_params[:email].split("@").first
      user.password = Devise.friendly_token[0, 20]
      user.save!
    end
    AccountUser.create!(account: current_account, user: user)

    redirect_to account_users_path, notice: "User was successfully added."
  end

  def update
    account_user = current_account.account_users.find(params[:id])
    authorize account_user

    account_user.update!(role: account_user_params[:role])
    redirect_to account_users_path, notice: "User role was successfully updated."
  end

  def destroy
    account_user = current_account.account_users.find(params[:id])
    authorize account_user

    account_user.destroy
    redirect_to account_users_path, notice: "User was successfully removed."
  end

  def index
    @pagy, @account_users = pagy(current_account.account_users)
  end


  private

  def user_params
    params.require(:user).permit(:email)
  end

  def account_user_params
    params.require(:account_user).permit(:role)
  end
end
