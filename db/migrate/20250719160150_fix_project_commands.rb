class FixProjectCommands < ActiveRecord::Migration[7.2]
  def change
    remove_column :projects, :predeploy_script, :text
    change_column :projects, :predeploy_command, :text
    rename_column :projects, :postdeploy_script, :postdeploy_command
    rename_column :projects, :predestroy_script, :predestroy_command
    rename_column :projects, :postdestroy_script, :postdestroy_command
  end
end
