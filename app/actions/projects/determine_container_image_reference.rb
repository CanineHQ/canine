class Projects::DetermineContainerImageReference
  extend LightService::Action
  expects :project
  promises :container_image_reference

  executed do |context|
    project = context.project

    context.container_image_reference = if project.build_configuration.present? && project.git?
      project.build_configuration.container_image_reference
    elsif project.public_image?
      tag = project.branch
      "#{project.repository_url.downcase}:#{tag}"
    else
      tag = project.git? ? project.branch.gsub('/', '-') : project.branch
      "#{project.project_credential_provider.provider.registry_base_url}/#{project.repository_url.downcase}:#{tag}"
    end
  end
end
