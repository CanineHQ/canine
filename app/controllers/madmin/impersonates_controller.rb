class Madmin::ImpersonatesController < Madmin::ApplicationController
  impersonates :user

  def impersonate
    user = User.find(params[:id])
    impersonate_user(user)
    redirect_to root_path
  end

  def stop_impersonating
    stop_impersonating_user
    redirect_to root_path
  end
end
