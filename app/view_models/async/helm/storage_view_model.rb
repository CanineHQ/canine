class Async::Helm::StorageViewModel < Async::BaseViewModel
  attr_reader :add_on, :service
  expects :add_on_id

  def add_on
    @add_on ||= current_user.add_ons.find(params[:add_on_id])
  end

  def service
    @service ||= K8::Helm::Service.new(K8::Connection.new(add_on, current_user))
  end

  def initial_render
    "<div class='loading loading-spinner loading-sm text-lg'></div>"
  end

  def render_error
    "<div class='text-yellow-500'>Error fetching storage metrics, pods might not be ready yet.</div>"
  end

  def async_render
    render "helm/storage", locals: { storage_metrics: service.storage_metrics }
  end
end
