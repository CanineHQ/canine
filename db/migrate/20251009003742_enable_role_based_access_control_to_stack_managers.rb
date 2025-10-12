class EnableRoleBasedAccessControlToStackManagers < ActiveRecord::Migration[7.2]
  def change
    add_column :stack_managers, :enable_role_based_access_control, :boolean, default: true
  end
end
