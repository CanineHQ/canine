module ProjectsHelper
  def project_layout(project, &block)
    render layout: 'projects/layout', locals: { project: }, &block
  end

  def project_root_path(project)
    project.development_environment? ? project_workbench_path(project) : project_deployments_path(project)
  end

  def project_root_url(project)
    project.development_environment? ? project_workbench_url(project) : project_deployments_url(project)
  end

  def selectable_providers_json(providers)
    providers.map { |p|
      { id: p.id, provider: p.provider, has_native_container_registry: p.has_native_container_registry? }
    }.to_json
  end
end
