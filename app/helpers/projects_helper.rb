module ProjectsHelper
  def project_layout(project, &block)
    render layout: 'projects/layout', locals: { project: }, &block
  end

  def selectable_providers_json(providers)
    providers.map { |p|
      { id: p.id, provider: p.provider, has_native_container_registry: p.has_native_container_registry? }
    }.to_json
  end
end
