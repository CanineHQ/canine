class CreateProjectForks < ActiveRecord::Migration[7.2]
  def change
    create_table :project_forks do |t|
      t.references :child_project, null: false, foreign_key: { to_table: :projects }, index: { unique: true }
      t.references :parent_project, null: false, foreign_key: { to_table: :projects }
      t.string :external_id, null: false

      t.string :number, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.string :user, null: false

      t.text :clean_up_command

      t.timestamps
    end
  end
end
