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
    ip = Networks::CheckDns.infer_expected_ip(ingress, connection)
    "<pre class='cursor-pointer' data-controller='clipboard' data-clipboard-text='#{ip}'>#{ip}</pre>"
  end
end
