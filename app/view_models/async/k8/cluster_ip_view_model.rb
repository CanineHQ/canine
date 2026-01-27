class Async::K8::ClusterIpViewModel < Async::BaseViewModel
  expects :service_id

  def service
    service ||= current_user.services.find(params[:service_id])
  end

  def initial_render
    "<div class='loading loading-spinner loading-sm'></div>"
  end

  def async_render
    connection = K8::Connection.new(service.project, current_user)
    ingress = K8::Stateless::Ingress.new(service)
    record = Dns::Utils.infer_expected_hostname(ingress, connection)
    if record[:type] == :ip_address
      ip = record[:value]
      <<~HTML
      <div class='flex items-center gap-2'>
        <pre>A Record</pre> / <pre class='cursor-pointer' data-controller='clipboard' data-clipboard-text='#{ip}'>#{ip}</pre>
      </div>
      HTML
    else
      hostname = record[:value]
      <<~HTML
      <div class='flex items-center gap-2'>
        <pre>CNAME Record</pre> / <pre class='cursor-pointer' data-controller='clipboard' data-clipboard-text='#{hostname}'>#{hostname}</pre>
      </div>
      HTML
    end
  end
end
