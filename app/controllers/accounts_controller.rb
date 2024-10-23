class AccountsController < ApplicationController
  def switch
    @account = current_user.accounts.find(params[:id])
    session[:account_id] = @account.id
    redirect_to root_path
  end

  def index
    @pagy, @accounts = pagy(current_user.accounts)
  end
end
