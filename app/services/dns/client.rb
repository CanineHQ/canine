class Dns::Client
  class Error < StandardError; end

  def self.for_provider(provider)
    case provider.to_s
    when "cloudflare"
      Dns::Cloudflare.new
    when "route53"
      Dns::Route53.new
    else
      raise Error, "Unsupported DNS provider: #{provider}"
    end
  end

  def self.default
    provider = ENV.fetch("DNS_PROVIDER", "cloudflare")
    for_provider(provider)
  end

  # Interface methods - subclasses must implement these

  def create_a_record(subdomain:, ip_address:, proxied: false, ttl: 300)
    raise NotImplementedError
  end

  def create_cname_record(subdomain:, target:, proxied: false, ttl: 300)
    raise NotImplementedError
  end

  def delete_record(subdomain:)
    raise NotImplementedError
  end

  def record_exists?(subdomain:)
    raise NotImplementedError
  end

  def find_record(subdomain:)
    raise NotImplementedError
  end

  def domain
    raise NotImplementedError
  end
end
