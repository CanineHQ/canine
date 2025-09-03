class Clusters::IsReady
  extend LightService::Action

  expects :connection

  executed do |context|
    client = K8::Client.new(context.connection)
    if client.can_connect?
      cluster.installing!
      cluster.success("Cluster is ready")
    else
      cluster.error("Cluster is not ready, retrying in 60 seconds...")
      context.fail_and_return!("Cluster is not ready")
    end
  end
end
