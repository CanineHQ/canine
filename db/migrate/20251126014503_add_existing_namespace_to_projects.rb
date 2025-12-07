class AddExistingNamespaceToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :namespace, :string
    add_column :projects, :managed_namespace, :boolean, default: true

    Project.all.each do |project|
      project.namespace = project.name
      project.save!
    end
    change_column_null :projects, :namespace, false

    add_column :add_ons, :namespace, :string
    add_column :add_ons, :managed_namespace, :boolean, default: true
    AddOn.all.each do |add_on|
      add_on.namespace = add_on.name
      add_on.save!
    end
    change_column_null :add_ons, :namespace, false
  end
end
