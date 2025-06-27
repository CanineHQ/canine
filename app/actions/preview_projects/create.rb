class PreviewProjects::Create
  extend LightService::Action

  expects :base_project, :pr
  promises :preview_project

  executed do |context|
    base_project = context.base_project
    pr = context.pr
    forked_project = base_project.dup
    forked_project.branch = pr.branch
    forked_project.name = "#{base_project.name}-#{pr.number}"
    # Duplicate the project_credential_provider
    new_project_credential_provider = base_project.project_credential_provider.dup
    new_project_credential_provider.project = forked_project

    # Duplicate the services
    base_project.services.map do |service|
      new_service = service.dup
      new_service.allow_public_networking = false
      new_service.project = forked_project
    end

    preview_project = PreviewProject.new(project: base_project)
    context.preview_project = preview_project
  end
end