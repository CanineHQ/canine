class CreateProjects < ActiveRecord::Migration[7.2]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :repository_url, null: false
      t.string :branch, default: "main", null: false
      t.references :cluster, null: false, foreign_key: true
      t.boolean :autodeploy, default: true, null: false
      t.string :dockerfile_path, default: "./Dockerfile", null: false
      t.string :docker_build_context_directory, default: ".", null: false
      t.string :docker_command
      t.string :predeploy_command
      t.integer :status, default: 0, null: false
      t.jsonb :canine_config, default: {}
      t.text :predeploy_script
      t.text :postdeploy_script
      t.text :predestroy_script
      t.text :postdestroy_script

      t.timestamps
    end
    add_index :projects, [ :name ], unique: true
  end
end
