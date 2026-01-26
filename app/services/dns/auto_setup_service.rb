class Dns::AutoSetupService
  attr_reader :service, :connection, :logger

  def initialize(service, connection:, logger: Rails.logger)
    @service = service
    @connection = connection
    @logger = logger
  end

  def self.enabled?
    ENV["ENABLE_AUTOMATIC_DNS_MAPPING"] == "true" && ENV["CLOUDFLARE_API_KEY"].present? && ENV["CLOUDFLARE_ZONE_ID"].present?
  end

  def call
    return unless self.class.enabled?
    return unless service.allow_public_networking?
    return unless service.web_service?

    hostname = fetch_ingress_hostname
    return unless hostname

    create_dns_record(hostname)
  rescue Dns::Client::Error => e
    logger.error("Failed to create DNS record: #{e.message}")
  rescue StandardError => e
    logger.error("DNS setup error: #{e.message}")
  end

  private

  def fetch_ingress_hostname
    ingress = K8::Stateless::Ingress.new(service)
    ingress.connect(connection)
    ingress.hostname
  end

  def create_dns_record(hostname)
    dns_client = Dns::Client.default

    if hostname[:type] == :ip_address
      create_a_record(dns_client, hostname[:value])
    else
      create_cname_record(dns_client, hostname[:value])
    end
  end

  def create_a_record(dns_client, ip_address)
    ip_address = infer_public_ip if private_ip?(ip_address)
    dns_client.create_a_record(subdomain: service.auto_subdomain, ip_address: ip_address)
    logger.info("Created DNS A record: #{service.auto_domain} -> #{ip_address}")
  end

  def create_cname_record(dns_client, target)
    dns_client.create_cname_record(subdomain: service.auto_subdomain, target: target)
    logger.info("Created DNS CNAME record: #{service.auto_domain} -> #{target}")
  end

  def private_ip?(ip)
    ip.start_with?("10.") || ip.start_with?("172.") || ip.start_with?("192.168.")
  end

  def infer_public_ip
    server_name = K8::Client.new(connection).server
    hostname = URI.parse(server_name).hostname

    if hostname.match?(/\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z/)
      hostname
    else
      Resolv.getaddress(hostname)
    end
  end
end
