class Clusters::IsReady
  extend LightService::Action

  expects :cluster, :user
  promises :kubectl

  executed do |context|
    cluster = context.cluster
    connection = K8::Connection.new(cluster, context.user)
    client = K8::Client.new(connection)
    runner = Cli::RunAndLog.new(cluster)
    context.kubectl = K8::Kubectl.new(connection, runner)
    if client.can_connect?
      cluster.installing!
      cluster.success("Cluster is ready")
    else
      cluster.error("Cluster is not ready, retrying in 60 seconds...")
      context.fail_and_return!("Cluster is not ready")
    end
  end
end
