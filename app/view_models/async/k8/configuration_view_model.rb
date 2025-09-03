class Async::K8::ConfigurationViewModel < Async::BaseViewModel
  expects :cluster_id

  def version
    cluster = current_user.clusters.find(params[:cluster_id])
    version ||= K8::Client.new(K8::Connection.new(cluster, current_user)).version['serverVersion']['gitVersion']
  end

  def initial_render
    "<div class='loading loading-spinner loading-sm'></div>"
  end

  def async_render
    "<div>#{version}</div>"
  end
end
