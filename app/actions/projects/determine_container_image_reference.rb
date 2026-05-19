class Projects::DetermineContainerImageReference
  extend LightService::Action
  expects :project
  promises :container_image_reference

  executed do |context|
    project = context.project

    context.container_image_reference = if project.build_configuration.present?
      project.build_configuration.container_image_reference
    else
      "#{project.repository_base_url}/#{project.repository_url.downcase}:#{project.branch}"
    end
  end
end
