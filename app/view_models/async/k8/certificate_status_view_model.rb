class Async::K8::CertificateStatusViewModel < Async::BaseViewModel
  attr_reader :service
  expects :service_id

  def service
    @service ||= current_user.services.find(params[:service_id])
  end

  def initial_render
    "<div class='flex items-center gap-2'>Certificate Status: <div class='loading loading-spinner loading-sm'></div></div>"
  end

  def connection
    @_connection ||= K8::Connection.new(service.project.cluster, current_user)
  end
  def async_render
    resource = if service.project.cluster.gateway_based?
      K8::Stateless::Gateway.new(service)
    else
      K8::Stateless::Ingress.new(service)
    end

    status = resource.connect(connection).certificate_status

    template = <<-HTML
      <div class="flex items-center gap-2">
        Certificate Status:
        <% if status == true %>
          <span class="text-success font-semibold">Issued</span>
        <% elsif status == :pending %>
          <span class="text-base-content/50 font-semibold">Pending</span>
        <% else %>
          <span class="text-warning font-semibold">Issuing</span>
        <% end %>
      </div>
    HTML

    ERB.new(template).result(binding)
  end
end
