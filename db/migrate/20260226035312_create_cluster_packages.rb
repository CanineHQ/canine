class CreateClusterPackages < ActiveRecord::Migration[7.2]
  def change
    create_table :cluster_packages do |t|
      t.references :cluster, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :config, default: {}
      t.datetime :installed_at

      t.timestamps
    end
    add_index :cluster_packages, [:cluster_id, :name], unique: true
  end
end
