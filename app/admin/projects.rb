ActiveAdmin.register Project do
  menu priority: 3
  config.filters = false
  index do
    selectable_column
    column :name
    column :users do |project|
      project.users.pluck(:email).join(", ")
    end
    column :status
    actions
  end

  actions :all, except: []
  show do
    attributes_table do
      row :name
      row :status
      h5 "users"
      ul do
        project.users.each do |user|
          li link_to(user.email, admin_user_path(user))
        end
      end
    end
  end
end
