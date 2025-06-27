class CreatePreviewProjects < ActiveRecord::Migration[7.2]
  def change
    create_table :preview_projects do |t|
      t.references :project, null: false, foreign_key: true
      #t.references :base_project, null: false, foreign_key: true
      t.string :external_id
      t.text :clean_up_command

      t.timestamps
    end
    add_index :preview_projects, :project_id, unique: true
  end
end
