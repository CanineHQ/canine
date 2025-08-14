class CreateBuildClouds < ActiveRecord::Migration[7.2]
  def change
    create_table :build_clouds do |t|
      t.references :cluster, null: false, foreign_key: true
      t.string :namespace, null: false, default: K8::BuildCloudManager::BUILDKIT_BUILDER_NAME
      t.integer :status, null: false, default: 0
      t.string :driver_version
      t.string :webhook_url
      t.jsonb :installation_metadata, default: {}
      t.datetime :installed_at
      t.text :error_message

      t.timestamps
    end
  end
end
