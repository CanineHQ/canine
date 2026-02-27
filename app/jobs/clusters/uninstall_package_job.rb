module Clusters
  class UninstallPackageJob < ApplicationJob
    queue_as :default

    def perform(cluster_package, user)
      cluster = cluster_package.cluster
      definition = cluster_package.definition
      return unless definition

      connection = K8::Connection.new(cluster, user)
      kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))

      cluster_package.uninstalling!
      cluster.info("Uninstalling #{definition['display_name']}...", color: :yellow)

      cluster_package.installer.uninstall!(kubectl)
      cluster_package.update!(status: :uninstalled)
      cluster.success("#{definition['display_name']} uninstalled successfully")
    rescue StandardError => e
      cluster_package.failed!
      cluster.error("#{definition['display_name']} failed to uninstall: #{e.message}")
    end
  end
end
