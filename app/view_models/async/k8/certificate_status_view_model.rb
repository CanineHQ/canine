class Async::K8::CertificateStatusViewModel < Async::BaseViewModel
  attr_reader :service
  expects :service_id

  def service
    @service ||= current_user.services.find(params[:service_id])
  end

  def initial_render
    "Certificate Status: <div class='loading loading-spinner loading-sm'></div>"
  end

  def connection
    @_connection ||= K8::Connection.new(service.project.cluster, current_user)
  end
  def async_render
    template = <<-HTML
      <div>
        Certificate Status:
        <% if K8::Stateless::Ingress.new(service).connect(connection).certificate_status %>
          <span class="text-success ml-2 font-semibold">Issued</span>
        <% else %>
          <span class="text-warning ml-2 font-semibold">Issuing</span>
        <% end %>
      </div>
    HTML

    ERB.new(template).result(binding)
  end
end
