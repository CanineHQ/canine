class Onboarding::CreateInClusterCluster
  extend LightService::Action
  expects :account, :user, :connect_cluster

  executed do |context|
    next context unless context.connect_cluster && K8::Connection.in_cluster?

    context[:cluster] = Cluster.create!(
      name: "in-cluster",
      account: context.account,
      options: { "in_cluster" => true },
      status: :running
    )

    # Sync packages to detect what's already installed (e.g. traefik, cert-manager from helm chart)
    Clusters::SyncPackages.execute(cluster: context[:cluster], user: context.user)
  end
end
