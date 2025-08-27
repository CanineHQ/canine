class Async::Clusters::BuildClouds::StatusViewModel < Async::BaseViewModel
  expects :build_cloud_id

  def build_cloud
    @build_cloud ||= current_user.build_clouds.find(params[:build_cloud_id])
  end

  def async_render
    manager = K8::BuildCloudManager.new(
      build_cloud.cluster.kubeconfig,
      build_cloud,
    )
    if manager.ensure_active!
      build_cloud.update(status: "active")
    else
      build_cloud.update(status: "failed")
    end
    render "clusters/build_clouds/status", locals: { build_cloud: }
  end

  def initial_render
    "<div class='text-sm loading loading-spinner loading-sm'></div>"
  end
end
