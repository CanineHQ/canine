ActiveAdmin.register User do
  menu priority: 2
  config.filters = false
  index do
    selectable_column
    column :email
    column :num_clusters do |user|
      user.clusters.count
    end
    column :num_projects do |user|
      user.projects.count
    end
    column :num_add_ons do |user|
      user.add_ons.count
    end
    column :created_at

    actions defaults: true do |user|
      link_to 'Login As', login_as_admin_user_path(user), method: :post
    end
  end

  member_action :login_as, method: :post do
    sign_in(:user, User.find(params[:id]), bypass: true)
    redirect_to root_path, notice: "Logged in as #{resource.email}"
  end

  action_item :login_as, only: [ :show ] do
    link_to 'Login As', login_as_admin_user_path(resource), method: :post
  end

  actions :all, except: []

  show do
    attributes_table do
      row :email
      row "Clusters" do |user|
        user.clusters.map { |cluster| link_to(cluster.name, admin_cluster_path(cluster)) }.join(", ").html_safe
      end
      row "Projects" do |user|
        user.projects.map { |project| link_to(project.name, admin_project_path(project)) }.join(", ").html_safe
      end
      row "Add Ons" do |user|
        user.add_ons.map { |add_on| link_to(add_on.name, admin_add_on_path(add_on)) }.join(", ").html_safe
      end
      row :created_at
      row :updated_at
    end
  end
end
