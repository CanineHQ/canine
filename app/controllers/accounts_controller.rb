class AccountsController < ApplicationController
  before_action :authorize_account, only: %i[update]

  def switch
    @account = current_user.accounts.friendly.find(params[:id])
    session[:account_id] = @account.id
    redirect_to root_path
  end

  def edit
    @account = current_account
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
      redirect_to edit_account_path(current_account), notice: "Account settings updated."
    else
      redirect_to edit_account_path(current_account), alert: current_account.errors.full_messages.to_sentence
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
