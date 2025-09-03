class KubeconfigNullOnCluster < ActiveRecord::Migration[7.2]
  def change
    change_column_null :clusters, :kubeconfig, true
    add_column :clusters, :external_id, :string

    create_table :stack_managers do |t|
      t.string :provider_url, null: false
      t.integer :stack_manager_type, null: false, default: 0
      t.references :account, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
