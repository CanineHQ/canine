class Onboarding::CreateInClusterCluster
  extend LightService::Action
  expects :account, :user
  expects :install_build_cloud, default: false
  expects :packages, default: nil
  promises :cluster

  executed do |context|
    context.cluster = Cluster.create!(
      name: "in-cluster",
      account: context.account,
      options: { "in_cluster" => true },
      status: :running
    )

    packages_params = context[:packages]
    if packages_params
      packages_params.each do |name, data|
        next unless data[:enabled] == "1"
        permitted_keys = ClusterPackage.permitted_config_keys(name)
        config = data[:config]&.permit(*permitted_keys)&.to_h || {}
        context.cluster.cluster_packages.create!(name: name, config: config)
      end
    else
      ClusterPackage.default_package_names.each do |name|
        context.cluster.cluster_packages.create!(name: name)
      end
    end

    Clusters::InstallJob.perform_later(context.cluster, context.user)

    if context.install_build_cloud
      build_cloud = context.cluster.create_build_cloud!
      Clusters::InstallBuildCloudJob.perform_later(build_cloud, context.user)
    end
  end
end
