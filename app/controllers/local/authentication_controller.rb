class Local::AuthenticationController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :load_account_from_slug
  before_action :check_if_passwordless_allowed

  def login
    if @account.stack_manager.present?
      redirect_to account_sign_in_path(@account.slug)
    elsif @account.users.count > 1
      redirect_to account_sign_in_path(@account.slug)
    else
      user = @account.owner
      sign_in(user)
      session[:account_id] = @account.id
      flash[:notice] = "Logged in successfully"
      redirect_to root_path
    end
  end

  private

  def load_account_from_slug
    @account = Account.friendly.find(params[:id])
  end

  def check_if_passwordless_allowed
    unless Rails.application.config.local_mode_passwordless
      redirect_to account_sign_in_path(@account)
    end
  end
end
