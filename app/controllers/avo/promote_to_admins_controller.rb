class Avo::PromoteToAdminsController < Avo::ApplicationController
  def create
    user = User.find(params[:user_id])
    User.where(id: user.id).update_all(admin: true)

    redirect_to avo.resources_user_path(user), notice: "#{user.name} has been promoted to site admin"
  end

  def destroy
    user = User.find(params[:user_id])
    User.where(id: user.id).update_all(admin: false)

    redirect_to avo.resources_user_path(user), notice: "#{user.name} has been demoted from site admin"
  end
end
