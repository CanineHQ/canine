class Onboarding::CreateInClusterCluster
  extend LightService::Action
  expects :account

  executed do |context|
    next context unless K8::Connection.in_cluster?

    context[:cluster] = Cluster.create!(
      name: "in-cluster",
      account: context.account,
      options: { "in_cluster" => true },
      status: :running
    )
  end
end
