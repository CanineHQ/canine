ActiveAdmin.register Cluster do
  menu priority: 5
  config.filters = false
  index do
    selectable_column
    column :name
    column :users do |cluster|
      cluster.users.pluck(:email).join(", ")
    end
    actions
  end

  actions :all, except: []
end
