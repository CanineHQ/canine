module Clusters
  class UninstallPackageJob < ApplicationJob
    queue_as :default

    def perform(cluster_package, user)
      cluster = cluster_package.cluster
      definition = cluster_package.definition
      return unless definition

      namespace = Clusters::Install::DEFAULT_NAMESPACE
      connection = K8::Connection.new(cluster, user)

      cluster_package.uninstalling!
      cluster.info("Uninstalling #{definition['display_name']}...", color: :yellow)

      case definition["install_type"]
      when "helm", "helm_and_manifest"
        runner = Cli::RunAndLog.new(cluster)
        helm = K8::Helm::Client.connect(connection, runner)
        helm.uninstall(definition["chart_name"], namespace: namespace)
      when "manifest"
        kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))
        manifest_path = definition["manifest_path"]
        kubectl.("delete -f #{Rails.root.join(manifest_path)} --ignore-not-found")
      end

      cluster_package.update!(status: :uninstalled)
      cluster.success("#{definition['display_name']} uninstalled successfully")
    rescue StandardError => e
      cluster_package.failed!
      cluster.error("#{definition['display_name']} failed to uninstall: #{e.message}")
    end
  end
end
