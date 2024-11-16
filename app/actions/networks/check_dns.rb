class Networks::CheckDns
  extend LightService::Action
  expects :ingress

  executed do |context|
    expected_ip = context.ingress.ip_address
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
