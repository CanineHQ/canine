class Onboarding::CreateInClusterCluster
  extend LightService::Action
  expects :account, :user, :connect_cluster
  expects :install_build_cloud, default: false

  executed do |context|
    next context unless context.connect_cluster && K8::Connection.in_cluster?

    context[:cluster] = Cluster.create!(
      name: "in-cluster",
      account: context.account,
      options: { "in_cluster" => true },
      status: :running
    )

    if context.install_build_cloud
      context[:cluster].create_build_cloud!
    end

    Clusters::InstallJob.perform_later(context[:cluster], context.user)
  end
end
