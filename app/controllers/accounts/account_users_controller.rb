class Accounts::AccountUsersController < ApplicationController
  include SettingsHelper
  def create
    email = user_params[:email].downcase
    existing_member = current_account.users.find_by(email: email)

    if existing_member
      redirect_to account_users_path, alert: "This user is already a member of this account."
      return
    end

    user = User.find_by(email: email)

    if user
      AccountUser.create!(account: current_account, user: user)
      redirect_to account_users_path, notice: "User was successfully added."
    else
      temp_password = generate_temp_password
      user = User.new(
        email: user_params[:email],
        password: temp_password,
        password_confirmation: temp_password,
        first_name: user_params[:email].split("@").first,
        password_change_required: true
      )
      user.skip_invitation = true
      user.save!
      AccountUser.create!(account: current_account, user: user)

      @invite_credentials = {
        email: user.email,
        password: temp_password,
        login_url: new_user_session_url
      }

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to account_users_path, notice: "User was successfully invited." }
      end
    end
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

  def generate_temp_password
    "#{SecureRandom.alphanumeric(8)}!#{SecureRandom.alphanumeric(4)}"
  end
end
