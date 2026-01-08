class Projects::HelmUninstallService < Projects::BaseUninstallService
  private

  def uninstall_resources
    helm_client = K8::Helm::Client.connect(@connection, Cli::RunAndLog.new(@project.cluster))
    helm_client.uninstall(@project.name, namespace: @project.namespace)
  end
end
