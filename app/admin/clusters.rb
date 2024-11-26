ActiveAdmin.register Cluster do
  config.filters = false
  index do
    selectable_column
    column :name
  end
  
  actions :all, except: []
end
