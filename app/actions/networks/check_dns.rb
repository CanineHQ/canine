class Networks::CheckDns
  extend LightService::Action
  expects :ingress, :connection

  class << self
    def infer_expected_ip(ingress, connection)
      ingress.connect(connection)
      ip = ingress.ip_address

      if is_private_ip?(ip)
        cluster = ingress.service.project.cluster
        ip = infer_public_ip_from_cluster(connection)
      end
      ip
    end

    def is_private_ip?(ip)
      ip.starts_with?("10.") || ip.starts_with?("172.") || ip.starts_with?("192.")
    end

    def infer_public_ip_from_cluster(connection)
      # The ingress is reporting a private IP address, so we need to guess the public IP address
      # based on the cluster's domain name
      server_name = K8::Client.new(connection).server
      # Parse the hostname from the server, with ruby's URI.parse
      hostname = URI.parse(server_name).hostname
      # If hostname is just an ip address, then we can return it
      if ip?(hostname)
        hostname
      else
        # Otherwise, we need to use Resolv to get the public IP address
        Resolv.getaddress(hostname)
      end
    end

    def ip?(ip)
      ip.match?(/\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z/)
    end
  end

  executed do |context|
    # TODO
    expected_ip = infer_expected_ip(context.ingress, context.connection)
    context.ingress.service.domains.each do |domain|
      ip_addresses = Resolv::DNS.open do |dns|
        dns.getresources(domain.domain_name, Resolv::DNS::Resource::IN::A).map do |resource|
          resource.address
        end
      end

      if ip_addresses.any? && ip_addresses.first.to_s == expected_ip
        domain.update(status: :dns_verified)
      else
        domain.update(status: :dns_incorrect, status_reason: "DNS record (#{ip_addresses.first}) does not match expected IP address (#{expected_ip})")
      end
    end
  end
end
