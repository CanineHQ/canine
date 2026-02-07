class UpdateContainerRegistryProjectsBranchToLatest < ActiveRecord::Migration[7.2]
  def up
    Project.joins(project_credential_provider: :provider).where(providers: { provider: 'container_registry' }).update_all(branch: 'latest')
  end

  def down
    # No-op: we can't know what the original branch values were
  end
end
