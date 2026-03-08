class AddMetadataToClusters < ActiveRecord::Migration[7.2]
  def up
    add_column :clusters, :metadata, :jsonb, default: {}, null: false

    execute <<~SQL
      UPDATE clusters
      SET metadata = COALESCE(metadata, '{}'::jsonb) || '{"networking_mode":"ingress"}'::jsonb
      WHERE NOT (COALESCE(metadata, '{}'::jsonb) ? 'networking_mode')
    SQL
  end

  def down
    remove_column :clusters, :metadata
  end
end
