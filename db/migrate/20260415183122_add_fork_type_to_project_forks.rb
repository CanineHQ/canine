class AddForkTypeToProjectForks < ActiveRecord::Migration[7.2]
  def change
    add_column :project_forks, :fork_type, :integer, default: 0, null: false
    change_column_null :project_forks, :number, true
    change_column_null :project_forks, :title, true
    change_column_null :project_forks, :url, true
    change_column_null :project_forks, :user, true
    change_column_null :project_forks, :external_id, true
  end
end
