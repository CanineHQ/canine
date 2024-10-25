class Accounts::AccountUsersController < ApplicationController
  before_action :set_account
  def create
    user = User.find_or_initialize_by(email: user_params[:email]) do |user|
      user.first_name = email.split("@").first
      user.password = Devise.friendly_token[0, 20]
      user.save!
    end
    AccountUser.create!(account: @account, user: user)

    redirect_to account_account_users_path(@account), notice: "User was successfully added."
  end

  def destroy
    @account.account_users.find(params[:id]).destroy

    redirect_to account_account_users_path(@account), notice: "User was successfully destroyed."
  end

  def index
    @pagy, @account_users = pagy(@account.account_users)
  end


  private

  def user_params
    params.require(:user).permit(:email)
  end

  def set_account
    @account = Account.find(params[:account_id])
  end
end
