class CreateClusters < ActiveRecord::Migration[7.2]
  def change
    create_table :clusters do |t|
      t.string :name, null: false
      t.jsonb :kubeconfig, null: false, default: {}
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
