module ProjectsHelper
  def project_layout(project, &block)
    render layout: 'projects/layout', locals: { project: }, &block
  end
end
