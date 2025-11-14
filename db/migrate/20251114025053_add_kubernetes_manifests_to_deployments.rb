class AddKubernetesManifestsToDeployments < ActiveRecord::Migration[7.2]
  def change
    add_column :deployments, :manifests, :jsonb
  end
end
