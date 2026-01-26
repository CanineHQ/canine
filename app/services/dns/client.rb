class Dns::Client
  class Error < StandardError; end

  def self.for_provider(provider)
    case provider.to_sym
    when :cloudflare
      Dns::Cloudflare.new
    else
      raise Error, "Unsupported DNS provider: #{provider}"
    end
  end

  def self.default
    Dns::Cloudflare.new(api_token: ENV["CLOUDFLARE_API_KEY"], zone_id: ENV["CLOUDFLARE_ZONE_ID"])
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
