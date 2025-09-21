class AccountsController < ApplicationController
  def switch
    @account = current_user.accounts.friendly.find(params[:id])
    session[:account_id] = @account.id
    redirect_to root_path
  end

  def show
  end

  def create
    account = current_user.accounts.create!(
      name: account_params[:name],
      owner: current_user
    )
    session[:account_id] = account.id
    redirect_to root_path
  end

  private

  def account_params
    params.require(:account).permit(:name)
  end
end
