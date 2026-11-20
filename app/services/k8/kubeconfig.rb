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
        cluster['cluster'].delete('certificate-authority')
        cluster['cluster'].delete('certificate-authority-data')
      end
      kubeconfig_hash
    end

    # When the bearer token in a kubeconfig stops working, if the token says so. Service account tokens
    # minted for people are JWTs with an expiry; client certificates and opaque tokens give nil.
    def self.token_expires_at(kubeconfig)
      payload = kubeconfig.dig("users", 0, "user", "token").to_s.split(".")[1]
      expiry = JSON.parse(Base64.urlsafe_decode64(payload.to_s))["exp"]
      Time.zone.at(expiry) if expiry.is_a?(Numeric)
    rescue JSON::ParserError, ArgumentError
      nil
    end

    def self.is_localhost?(address)
      host = URI.parse(address).host
      host == "127.0.0.1" || host == "localhost"
    rescue URI::InvalidURIError
      false
    end

    def self.remap_localhost(address, remap_host = Rails.configuration.remap_localhost)
      if is_localhost?(address)
        uri = URI.parse(address)
        uri.host = remap_host
        uri.to_s
      else
        address
      end
    end
  end
end
