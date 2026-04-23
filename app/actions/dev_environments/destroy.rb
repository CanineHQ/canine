class DevEnvironments::Destroy
  extend LightService::Action

  expects :project

  executed do |context|
    project = context.project

    # Disconnect parent → child fork records
    project.dev_environment_forks.destroy_all

    # Disconnect child → parent fork record
    project.child_dev_environment_fork&.destroy
  end
end
