class Clusters::SyncPackages
  extend LightService::Action
  expects :cluster, :user

  executed do |context|
    cluster = context.cluster
    user = context.user

    connection = K8::Connection.new(cluster, user)
    kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))

    cluster.info("Syncing package statuses...", color: :yellow)

    ClusterPackage.definitions.each do |definition|
      package = cluster.cluster_packages.find_by(name: definition["name"])
      check_package = package || cluster.cluster_packages.build(name: definition["name"])
      found = check_package.installer.installed?(kubectl)

      if found
        if package
          unless package.installed?
            package.update!(status: :installed, installed_at: package.installed_at || Time.current)
          end
        else
          cluster.cluster_packages.create!(name: definition["name"], status: :installed, installed_at: Time.current)
        end
      elsif package&.installed?
        package.update!(status: :uninstalled)
      end
    end

    cluster.success("Package sync complete")
  end
end
