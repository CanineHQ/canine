module K8
  module Kubeconfig
    def with_kube_config
      Tempfile.open(['kubeconfig', '.yaml']) do |kubeconfig_file|
        kubeconfig_hash = kubeconfig.is_a?(String) ? JSON.parse(kubeconfig) : kubeconfig
        kubeconfig_file.write(kubeconfig_hash.to_yaml)
        kubeconfig_file.flush
        yield kubeconfig_file
      end
    end
  end
end
