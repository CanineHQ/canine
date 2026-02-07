class Networks::CheckDns
  extend LightService::Action
  expects :ingress, :connection

  executed do |context|
    expected_dns = Dns::Utils.infer_expected_hostname(context.ingress, context.connection)
    context.ingress.service.domains.each do |domain|
      if expected_dns[:type] == :ip_address
        ip_addresses = Resolv::DNS.open do |dns|
          dns.getresources(domain.domain_name, Resolv::DNS::Resource::IN::A).map do |resource|
            resource.address
          end
        end

        if ip_addresses.any? && ip_addresses.first.to_s == expected_dns[:value]
          domain.update(status: :dns_verified)
        else
          domain.update(status: :dns_incorrect, status_reason: "DNS record (#{ip_addresses.first || "empty"}) does not match expected IP address (#{expected_dns[:value]})")
        end
      else
        hostnames = Resolv::DNS.open do |dns|
          dns.getresources(domain.domain_name, Resolv::DNS::Resource::IN::CNAME).map do |resource|
            resource.name
          end
        end
        if hostnames.any? && hostnames.first.to_s == expected_dns[:value]
          domain.update(status: :dns_verified)
        else
          domain.update(status: :dns_incorrect, status_reason: "DNS record (#{hostnames.first || "empty"}) does not match expected hostname (#{expected_dns[:value]})")
        end
      end
    end
  end
end
