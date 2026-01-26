class Dns::AutoSetupService
  attr_reader :service, :connection, :logger

  def initialize(service, connection:, logger: Rails.logger)
    @service = service
    @connection = connection
    @logger = logger
  end

  def self.enabled?
    ENV["ENABLE_AUTOMATIC_DNS_MAPPING"] == "true" &&
      ENV["CLOUDFLARE_API_KEY"].present? &&
      ENV["CLOUDFLARE_ZONE_ID"].present?
  end

  def call
    return unless self.class.enabled?
    return unless service.allow_public_networking?
    return unless service.web_service?

    logger.info("Setting up automatic DNS for #{service.name}")

    hostname = fetch_expected_hostname
    return unless hostname

    create_dns_record(hostname)
  rescue Dns::Client::Error => e
    logger.error("Failed to create DNS record for #{service.name}: #{e.message}")
  rescue StandardError => e
    logger.error("DNS setup failed for #{service.name}: #{e.message}")
  end

  private

  def fetch_expected_hostname
    ingress = K8::Stateless::Ingress.new(service)
    Dns::Utils.infer_expected_hostname(ingress, connection)
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
    dns_client.create_a_record(subdomain: service.auto_subdomain, ip_address: ip_address)
    logger.success("Created A record: #{service.auto_domain} -> #{ip_address}")
  end

  def create_cname_record(dns_client, target)
    dns_client.create_cname_record(subdomain: service.auto_subdomain, target: target)
    logger.success("Created CNAME record: #{service.auto_domain} -> #{target}")
  end
end
