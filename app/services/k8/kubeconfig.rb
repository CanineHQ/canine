module K8
  module Kubeconfig
    def self.skip_tls_verify?
      !ENV['VERIFY_CLUSTER_TLS'].present?
    end

    def self.skip_tls_env
      skip_tls_verify? ? { "SKIP_TLS_VERIFY" => "true" } : {}
    end

    def with_kube_config
      Tempfile.open([ 'kubeconfig', '.yaml' ]) do |kubeconfig_file|
        kubeconfig_hash = kubeconfig.is_a?(String) ? JSON.parse(kubeconfig) : kubeconfig
        kubeconfig_hash = apply_tls_settings(kubeconfig_hash)
        kubeconfig_file.write(kubeconfig_hash.to_yaml)
        kubeconfig_file.flush
        yield kubeconfig_file
      end
    end

    private

    def apply_tls_settings(kubeconfig_hash)
      return kubeconfig_hash if ENV['VERIFY_CLUSTER_TLS'].present?

      kubeconfig_hash = kubeconfig_hash.deep_dup
      kubeconfig_hash['clusters']&.each do |cluster|
        cluster['cluster']['insecure-skip-tls-verify'] = true
      end
      kubeconfig_hash
    end
  end
end
