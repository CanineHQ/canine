class AddClusterTypeToClusters < ActiveRecord::Migration[7.2]
  def change
    add_column :clusters, :cluster_type, :integer, default: 0
    Cluster.update_all(cluster_type: :k8s)
  end
end
