class Async::Helm::VersionViewModel < Async::BaseViewModel
  expects :add_on_id

  def service
    @add_on ||= current_user.add_ons.find(params[:add_on_id])
    connection = K8::Connection.new(@add_on, current_user)
    @service ||= K8::Helm::Service.new(connection)
  end

  def initial_render
    render "shared/components/field_skeleton", locals: { size: :medium }
  end

  def async_render
    "<div>#{service.version}</div>"
  end
end
