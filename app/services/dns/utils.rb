class Dns::Utils
  class << self
    def private_ip?(ip)
      ip.start_with?("10.") || ip.start_with?("172.") || ip.start_with?("192.168.")
    end

    def ip_address?(str)
      str.match?(/\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z/)
    end

    def infer_public_ip(connection)
      server_name = K8::Client.new(connection).server
      hostname = URI.parse(server_name).hostname

      if ip_address?(hostname)
        hostname
      else
        Resolv.getaddress(hostname)
      end
    end

    def infer_expected_hostname(ingress, connection)
      ingress.connect(connection)
      hostname = ingress.hostname

      # Only try to infer a public IP address if the cluster is a single node cluster (k3s, local_k3s)
      if !connection.cluster.k8s? && hostname[:type] == :ip_address && private_ip?(hostname[:value])
        public_ip = infer_public_ip(connection)
        { type: :ip_address, value: public_ip }
      elsif hostname[:type] == :ip_address && private_ip?(hostname[:value])
        raise "Private IP address detected for cluster type: #{connection.cluster.cluster_type}"
      else
        hostname
      end
    end
  end
end
