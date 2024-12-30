ActiveAdmin.register User do
  config.filters = false
  index do
    selectable_column
    column :email
    column :num_projects do |user|
      user.projects.count
    end
    actions defaults: true do |user|
      link_to 'Login As', login_as_admin_user_path(user), method: :post
    end
  end

  actions :all, except: []

  member_action :login_as, method: :post do
    sign_in(:user, User.find(params[:id]), bypass: true)
    redirect_to root_path, notice: "Logged in as #{resource.email}"
  end
end
