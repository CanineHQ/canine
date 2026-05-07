class CreateDevelopmentEnvironments < ActiveRecord::Migration[7.2]
  def change
    create_table :development_environments do |t|
      t.references :child_project, null: false, foreign_key: { to_table: :projects }, index: { unique: true }
      t.references :parent_project, null: false, foreign_key: { to_table: :projects }
      t.references :git_provider, null: false, foreign_key: { to_table: :providers }, index: { name: "index_dev_envs_on_git_provider_id" }

      t.timestamps
    end
  end
end
