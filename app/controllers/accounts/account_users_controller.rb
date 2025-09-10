class Accounts::AccountUsersController < ApplicationController
  def create
    user = User.find_or_initialize_by(email: user_params[:email]) do |user|
      user.first_name = user_params[:email].split("@").first
      user.password = Devise.friendly_token[0, 20]
      user.save!
    end
    AccountUser.create!(account: current_account, user: user)

    redirect_to account_account_users_path(current_account), notice: "User was successfully added."
  end

  def destroy
    current_account.account_users.find(params[:id]).destroy

    redirect_to account_account_users_path(current_account), notice: "User was successfully destroyed."
  end

  def index
    @pagy, @account_users = pagy(current_account.account_users)
  end


  private

  def user_params
    params.require(:user).permit(:email)
  end
end
