class Avo::ImpersonationsController < Avo::ApplicationController
  impersonates :user

  before_action :require_admin, only: :create

  def create
    user = User.find(params[:user_id])
    impersonate_user(user)
    # Set account to the impersonated user's first account
    session[:account_id] = user.accounts.first&.id
    redirect_to main_app.root_path, notice: "Now impersonating #{user.name}"
  end

  def destroy
    stop_impersonating_user
    redirect_to main_app.root_path, notice: "Stopped impersonating"
  end

  private

  def require_admin
    unless true_user&.admin?
      redirect_to main_app.root_path, alert: "Not authorized"
    end
  end
end
