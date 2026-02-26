module Clusters
  class InstallPackageJob < ApplicationJob
    queue_as :default

    def perform(cluster_package, user)
      cluster = cluster_package.cluster
      definition = cluster_package.definition
      return unless definition

      namespace = Clusters::Install::DEFAULT_NAMESPACE
      connection = K8::Connection.new(cluster, user)
      kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))

      cluster_package.installing!
      cluster.info("Installing #{definition['display_name']}...", color: :yellow)

      Clusters::InstallComponents.install_package(cluster, kubectl, connection, cluster_package, definition, namespace)
      cluster_package.update!(status: :installed, installed_at: Time.current)
      cluster.success("#{definition['display_name']} installed successfully")
    rescue StandardError => e
      cluster_package.failed!
      cluster.error("#{definition['display_name']} failed to install: #{e.message}")
    end
  end
end
