module ServicesHelper
  def services_layout(service, tab, &block)
    render layout: 'projects/services/layout', locals: { service:, tab: }, &block
  end
end
