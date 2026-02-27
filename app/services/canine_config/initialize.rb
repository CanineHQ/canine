class CanineConfig::Initialize
  extend LightService::Action
  expects :project

  executed do |context|
    project = context.project
    next if project.canine_config.blank?

    definition = CanineConfig::Definition.new(project.canine_config)

    definition.services.each do |service|
      service.project = project
      service.save!
    end

    definition.environment_variables.each do |env_var|
      project.environment_variables.create!(
        name: env_var.name,
        value: env_var.value,
        storage_type: env_var.storage_type
      )
    end

    definition.volumes.each do |volume|
      project.volumes.create!(
        name: volume.name,
        size: volume.size,
        mount_path: volume.mount_path,
        access_mode: volume.access_mode
      )
    end

    definition.notifiers.each do |notifier|
      project.notifiers.create!(
        name: notifier.name,
        provider_type: notifier.provider_type,
        webhook_url: notifier.webhook_url,
        enabled: notifier.enabled
      )
    end
  end
end
