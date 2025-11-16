class AddStorageTypeToEnvironmentVariables < ActiveRecord::Migration[7.2]
  def change
    add_column :environment_variables, :storage_type, :integer, default: 0, null: false
  end
end
