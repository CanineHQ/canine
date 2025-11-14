module ServicesHelper
  def services_layout(service, tab, &block)
    render layout: 'services/layout', locals: { service:, tab: }, &block
  end
end