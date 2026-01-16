module K8
  module Kubeconfig
    def self.with_kube_config(kubeconfig, skip_tls_verify: false)
      Tempfile.open([ 'kubeconfig', '.yaml' ]) do |kubeconfig_file|
        kubeconfig_hash = kubeconfig.is_a?(String) ? JSON.parse(kubeconfig) : kubeconfig
        kubeconfig_hash = apply_tls_settings(kubeconfig_hash, skip_tls_verify)
        kubeconfig_file.write(kubeconfig_hash.to_yaml)
        kubeconfig_file.flush
        yield kubeconfig_file
      end
    end

    def self.apply_tls_settings(kubeconfig_hash, skip_tls_verify)
      return kubeconfig_hash unless skip_tls_verify

      kubeconfig_hash = kubeconfig_hash.deep_dup
      kubeconfig_hash['clusters']&.each do |cluster|
        cluster['cluster']['insecure-skip-tls-verify'] = true
      end
      kubeconfig_hash
    end
  end
end
