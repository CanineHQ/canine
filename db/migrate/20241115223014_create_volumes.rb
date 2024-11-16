class CreateVolumes < ActiveRecord::Migration[7.2]
  def change
    create_table :volumes do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.string :size, default: "10Gi", null: false
      t.integer :access_mode, default: 0
      t.string :mount_path, null: false, default: "/volumes/data"
      t.integer :status, default: 0

      t.timestamps
    end
    add_index :volumes, [:project_id, :name], unique: true
    add_index :volumes, [:project_id, :mount_path], unique: true
  end
end
