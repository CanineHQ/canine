class AccountsController < ApplicationController
  before_action :authorize_account, only: %i[update]

  def switch
    @account = current_user.accounts.friendly.find(params[:id])
    session[:account_id] = @account.id
    redirect_to root_path
  end

  def show
  end

  def create
    account = Account.create!(
      name: account_params[:name],
      owner: current_user
    )
    AccountUser.create!(account: account, user: current_user, role: :owner)
    session[:account_id] = account.id
    redirect_to root_path
  end

  def update
    if current_account.update(account_params)
      redirect_to edit_user_registration_path, notice: "Account settings updated."
    else
      redirect_to edit_user_registration_path, alert: current_account.errors.full_messages.to_sentence
    end
  end

  private

  def account_params
    params.require(:account).permit(:name, :allow_mcp)
  end

  def authorize_account
    authorize current_account, :update?
  end
end
