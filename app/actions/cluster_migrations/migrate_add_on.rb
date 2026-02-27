class ClusterMigrations::MigrateAddOn
  extend LightService::Action

  expects :source_add_on, :target_cluster
  expects :custom_name, :custom_namespace, :managed_namespace
  promises :migrated_add_on

  executed do |context|
    source = context.source_add_on
    target_cluster = context.target_cluster

    ActiveRecord::Base.transaction do
      add_on = source.dup
      add_on.cluster_id = target_cluster.id
      add_on.status = :installing
      add_on.metadata = (source.metadata || {}).merge("install_stage" => 0)

      # Generate unique name within the account
      base_name = context.custom_name || source.name
      add_on.name = base_name
      while AddOn.joins(:cluster).where(clusters: { account_id: target_cluster.account_id }, name: add_on.name).exists?
        add_on.name = "#{base_name}-#{SecureRandom.hex(4)}"
      end
      add_on.namespace = context.custom_namespace || add_on.name
      add_on.managed_namespace = context.managed_namespace if context.custom_namespace.present?
      add_on.save!

      context.migrated_add_on = add_on
    end
  rescue StandardError => e
    context.fail_and_return!("Failed to migrate add-on: #{e.message}")
  end
end
