ActiveAdmin.register AddOn do
  menu priority: 4
  config.filters = false
  index do
    selectable_column
    column :name
    column :cluster do |add_on|
      add_on.cluster.name
    end
    column :owner do |add_on|
      add_on.account.name
    end
    column :status
    column :created_at
    actions
  end

  actions :all, except: []
end
