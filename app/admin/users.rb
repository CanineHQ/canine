ActiveAdmin.register User do
  config.filters = false
  index do
    selectable_column
    column :email
    column :num_projects do |user|
      user.projects.count
    end
  end

  actions :all, except: []
end
