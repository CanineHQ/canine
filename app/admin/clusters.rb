ActiveAdmin.register Cluster do
  config.filters = false
  index do
    selectable_column
    column :name
    column :users do |cluster|
      cluster.users.pluck(:email).join(", ")
    end
  end

  actions :all, except: []
end
