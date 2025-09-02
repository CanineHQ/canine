class CreateBuildClouds < ActiveRecord::Migration[7.2]
  def change
    create_table :build_clouds do |t|
      t.references :cluster, null: false, foreign_key: true
      t.string :namespace, null: false, default: K8::BuildCloudManager::BUILDKIT_BUILDER_DEFAULT_NAMESPACE
      t.integer :status, null: false, default: 0
      t.string :driver_version
      t.string :webhook_url
      t.jsonb :installation_metadata, default: {}
      t.datetime :installed_at
      t.text :error_message
      t.integer :replicas, default: 2
      t.bigint :cpu_requests, default: 500
      t.bigint :cpu_limits, default: 2000
      t.bigint :memory_requests, default: 536870912 # 512Mi in bytes
      t.bigint :memory_limits, default: 4294967296 # 4Gi in bytes

      t.timestamps
    end
  end
end
