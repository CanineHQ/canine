class ClusterMigrations::MigrateProject
  extend LightService::Action

  expects :source_project, :target_cluster
  promises :migrated_project

  executed do |context|
    source = context.source_project
    target_cluster = context.target_cluster

    ActiveRecord::Base.transaction do
      project = source.dup
      project.cluster_id = target_cluster.id
      project.status = :creating
      project.current_deployment_id = nil

      # Generate unique name and slug for the target account
      base_name = source.name
      project.name = base_name
      while Project.joins(:cluster).where(clusters: { account_id: target_cluster.account_id }, name: project.name).exists?
        project.name = "#{base_name}-#{SecureRandom.hex(4)}"
      end
      project.namespace = project.name
      project.slug = nil
      project.generate_slug

      # Duplicate credential provider
      credential_provider = source.project_credential_provider.dup
      credential_provider.project = project

      # Duplicate build configuration
      if source.build_configuration.present?
        project.build_configuration = source.build_configuration.dup
      end

      # Duplicate deployment configuration
      if source.deployment_configuration.present?
        project.deployment_configuration = source.deployment_configuration.dup
      end

      project.save!
      credential_provider.save!

      # Duplicate services with associations
      source.services.each do |service|
        new_service = service.dup
        new_service.project = project
        new_service.save!

        if service.resource_constraint.present?
          new_constraint = service.resource_constraint.dup
          new_constraint.service = new_service
          new_constraint.save!
        end

        if service.cron_schedule.present?
          new_schedule = service.cron_schedule.dup
          new_schedule.service = new_service
          new_schedule.save!
        end

        service.domains.each do |domain|
          new_domain = domain.dup
          new_domain.service = new_service
          new_domain.save!
        end
      end

      # Duplicate environment variables
      source.environment_variables.each do |env_var|
        new_env = env_var.dup
        new_env.project = project
        new_env.save!
      end

      # Duplicate volumes
      source.volumes.each do |volume|
        new_volume = volume.dup
        new_volume.project = project
        new_volume.status = :pending
        new_volume.save!
      end

      # Duplicate notifiers
      source.notifiers.each do |notifier|
        new_notifier = notifier.dup
        new_notifier.project = project
        new_notifier.save!
      end

      context.migrated_project = project
    end
  rescue StandardError => e
    context.fail_and_return!("Failed to migrate project: #{e.message}")
  end
end
