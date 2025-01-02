class AddContainerRegistryUrlToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :container_registry_url, :string
  end
end
