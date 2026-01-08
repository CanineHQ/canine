class AddVersionToDeployments < ActiveRecord::Migration[7.2]
  def change
    add_column :deployments, :version, :string
  end
end
