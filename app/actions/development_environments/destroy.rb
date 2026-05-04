class DevelopmentEnvironments::Destroy
  extend LightService::Action

  expects :project

  executed do |context|
    project = context.project

    # Disconnect parent → child fork records
    project.development_environments.destroy_all

    # Disconnect child → parent fork record
    project.child_development_environment&.destroy
  end
end
