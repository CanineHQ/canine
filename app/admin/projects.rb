ActiveAdmin.register Project do
  config.filters = false
  index do
    selectable_column
    column :name
    column :users do |project|
      project.users.pluck(:email).join(", ")
    end
  end
  
  actions :all, except: []
end
