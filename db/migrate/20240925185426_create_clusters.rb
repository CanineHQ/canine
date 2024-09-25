class CreateClusters < ActiveRecord::Migration[7.1]
  def change
    create_table :clusters do |t|
      t.string :name, null: false
      t.jsonb :kubeconfig, null: false, default: {}
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
