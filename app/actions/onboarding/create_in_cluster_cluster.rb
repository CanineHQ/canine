class Onboarding::CreateInClusterCluster
  extend LightService::Action
  expects :account, :connect_cluster

  executed do |context|
    next context unless context.connect_cluster && K8::Connection.in_cluster?

    context[:cluster] = Cluster.create!(
      name: "in-cluster",
      account: context.account,
      options: { "in_cluster" => true },
      status: :running
    )
  end
end
