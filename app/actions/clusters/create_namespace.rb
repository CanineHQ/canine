class Clusters::CreateNamespace
  extend LightService::Action

  expects :cluster

  executed do |context|
    cluster = context.cluster
    runner = Cli::RunAndLog.new(cluster)
    kubectl = K8::Kubectl.new(cluster.kubeconfig, runner)
    kubectl.apply_yaml(K8::Namespace.new(Struct.new(:name).new(Clusters::Install::DEFAULT_NAMESPACE)).to_yaml)
  end
end
