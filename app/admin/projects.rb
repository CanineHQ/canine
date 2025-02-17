ActiveAdmin.register Project do
  menu priority: 3
  config.filters = false
  index do
    selectable_column
    column :name
    column :users do |project|
      project.users.pluck(:email).join(", ")
    end
    actions
  end

  actions :all, except: []
end
