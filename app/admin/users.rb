ActiveAdmin.register User do
  config.filters = false
  index do
    selectable_column
    column :email
  end
  
  actions :all, except: []
end
