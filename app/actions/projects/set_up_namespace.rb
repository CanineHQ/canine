class Projects::SetUpNamespace
  extend LightService::Action
  expects :project

  executed do |context|
    project = context.project
    if project.namespace.blank? && project.managed_namespace
      # autoset the namespace to the project name
      project.namespace = project.name
    elsif project.namespace.blank? && !project.managed_namespace
      project.errors.add(:base, "A namespace must be provided if it is not managed by Canine")
      context.fail_and_return!("Failed to set up namespace")
    end
  end
end
