class Clusters::InstallNginxIngress
  extend LightService::Action

  expects :cluster

  executed do |context|
    cluster = context.cluster
    runner = Cli::RunAndLog.new(cluster)
    kubectl = K8::Kubectl.new(cluster.kubeconfig, runner)
    cluster.info("Checking if Nginx ingress controller is already installed...")

    begin
      kubectl.("get deployment ingress-nginx-controller")
      cluster.info("Nginx ingress controller is already installed")
    rescue Cli::CommandFailedError => e
      cluster.info("Nginx ingress controller not detected, installing...")
      command = "bash #{Rails.root.join("resources", "k8", "scripts", "install_cert_manager.sh")}"
      kubectl.with_kube_config do |kubeconfig_file|
        begin
          runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
          cluster.info("Nginx ingress controller installed successfully")
        rescue Cli::CommandFailedError => e
          cluster.failed!
          cluster.info("Cert manager failed to install")
          context.fail!("Script failed with exit code #{exit_status.exitstatus}")
        end
      end
    end
  end
end