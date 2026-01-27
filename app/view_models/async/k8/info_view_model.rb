class Async::K8::InfoViewModel < Async::BaseViewModel
  expects :cluster_id

  def server
    cluster = current_user.clusters.find(params[:cluster_id])
    K8::Client.new(K8::Connection.new(cluster, current_user)).server
  end

  def initial_render
    "<div class='loading loading-spinner loading-sm'></div>"
  end

  def async_render
    "<div class='text-sm text-gray-500'>#{server}</div>"
  end
end
