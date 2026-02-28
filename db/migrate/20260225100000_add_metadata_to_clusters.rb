class AddMetadataToClusters < ActiveRecord::Migration[7.2]
  def up
    add_column :clusters, :metadata, :jsonb, default: {}, null: false

    execute <<~SQL
      UPDATE clusters
      SET metadata = COALESCE(metadata, '{}'::jsonb) || '{"networking_mode":"ingress"}'::jsonb
      WHERE NOT (COALESCE(metadata, '{}'::jsonb) ? 'networking_mode')
    SQL

    execute <<~SQL
      UPDATE clusters
      SET metadata = COALESCE(metadata, '{}'::jsonb) || '{"networking_mode":"gateway"}'::jsonb
      WHERE id IN (
        SELECT DISTINCT projects.cluster_id
        FROM deployments
        INNER JOIN builds ON builds.id = deployments.build_id
        INNER JOIN projects ON projects.id = builds.project_id
        WHERE deployments.manifests::text ILIKE '%gateway.networking.k8s.io%'
           OR deployments.manifests::text ILIKE '%kind: Gateway%'
           OR deployments.manifests::text ILIKE '%kind: HTTPRoute%'
      )
    SQL
  end

  def down
    remove_column :clusters, :metadata
  end
end
