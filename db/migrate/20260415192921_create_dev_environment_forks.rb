class CreateDevEnvironmentForks < ActiveRecord::Migration[7.2]
  def change
    create_table :dev_environment_forks do |t|
      t.references :child_project, null: false, foreign_key: { to_table: :projects }, index: { unique: true }
      t.references :parent_project, null: false, foreign_key: { to_table: :projects }

      t.timestamps
    end
  end
end
