class Projects::DetermineContainerImageReference
  extend LightService::Action
  expects :project
  promises :container_image_reference

  executed do |context|
    project = context.project
    provider = project.build_provider

    context.container_image_reference = if project.build_configuration.present? && project.git?
      project.build_configuration.container_image_reference
    else
      tag = project.git? ? project.branch.gsub('/', '-') : 'latest'
      "#{project.project_credential_provider.provider.registry_base_url}/#{project.repository_url}:#{tag}"
    end
  end
end
