class Onboarding::CreateInClusterCluster
  extend LightService::Action
  expects :account, :user
  expects :install_build_cloud, default: false
  promises :cluster

  executed do |context|
    context.cluster = Cluster.create!(
      name: "in-cluster",
      account: context.account,
      options: { "in_cluster" => true },
      status: :running
    )

    if context.install_build_cloud
      context.cluster.create_build_cloud!
    end

    Clusters::InstallJob.perform_later(context.cluster, context.user)
  end
end
