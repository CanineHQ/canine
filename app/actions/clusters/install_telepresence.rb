class Clusters::InstallTelepresence
  extend LightService::Action
  expects :cluster, :kubectl

  executed do |context|
    cluster = context.cluster
    kubectl = context.kubectl
    cluster.info("Checking if Telepresence is already installed...", color: :yellow)

    begin
      kubectl.("get deployment traffic-manager -n #{Clusters::Install::DEFAULT_NAMESPACE}")
      cluster.success("Telepresence already installed")
    rescue Cli::CommandFailedError => e
      cluster.info("Telepresence not detected, installing...", color: :yellow)
      command = "bash #{Rails.root.join("resources", "k8", "scripts", "install_telepresence.sh")}"
      kubectl.with_kube_config do |kubeconfig_file|
        begin
          runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path, "NAMESPACE" => Clusters::Install::DEFAULT_NAMESPACE })
          cluster.success("Telepresence installed successfully")
        rescue Cli::CommandFailedError => e
          cluster.failed!
          cluster.error("Telepresence failed to install")
          context.fail_and_return!("Script failed with exit code #{e.message}")
        end
      end
    end
  end
end
