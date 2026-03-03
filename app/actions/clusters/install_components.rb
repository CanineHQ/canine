class Clusters::InstallComponents
  extend LightService::Action

  expects :cluster, :kubectl, :connection

  executed do |context|
    cluster = context.cluster
    kubectl = context.kubectl

    cluster.cluster_packages.where(status: [ :pending, :failed ]).find_each do |package|
      definition = package.definition
      next unless definition

      package.installing!
      cluster.info("Installing #{definition['display_name']}...", color: :yellow)

      begin
        installer = package.installer

        if installer.installed?(kubectl)
          cluster.success("#{definition['display_name']} is already installed")
          package.update!(status: :installed, installed_at: Time.current)
          next
        end

        installer.install!(kubectl)
        package.update!(status: :installed, installed_at: Time.current)
        cluster.success("#{definition['display_name']} installed successfully")
      rescue StandardError => e
        package.failed!
        cluster.error("#{definition['display_name']} failed to install: #{e.message}")
      end
    end
  end
end
