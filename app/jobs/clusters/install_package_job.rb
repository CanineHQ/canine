module Clusters
  class InstallPackageJob < ApplicationJob
    queue_as :default

    def perform(cluster_package, user)
      cluster = cluster_package.cluster
      definition = cluster_package.definition
      return unless definition

      connection = K8::Connection.new(cluster, user)
      kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))

      if cluster_package.installer.installed?(kubectl)
        cluster_package.update!(status: :installed, installed_at: cluster_package.installed_at || Time.current)
        cluster.info("#{definition['display_name']} is already installed. Uninstall first to reinstall with new settings.", color: :yellow)
        return
      end

      cluster_package.installing!
      cluster.info("Installing #{definition['display_name']}...", color: :yellow)

      cluster_package.installer.install!(kubectl)
      cluster_package.update!(status: :installed, installed_at: Time.current)
      cluster.success("#{definition['display_name']} installed successfully")
    rescue StandardError => e
      cluster_package.failed!
      cluster.error("#{definition['display_name']} failed to install: #{e.message}")
    end
  end
end
