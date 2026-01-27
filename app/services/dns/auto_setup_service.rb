class Dns::AutoSetupService
  attr_reader :domain, :connection, :logger

  def initialize(domain, connection:, logger: Rails.logger)
    @domain = domain
    @connection = connection
    @logger = logger
  end

  def self.enabled?
    ENV["ENABLE_AUTOMATIC_DNS_MAPPING"] == "true" &&
      Dns::Cloudflare::API_TOKEN.present? &&
      Dns::Cloudflare::ZONE_ID.present?
  end

  def call
    return unless self.class.enabled?

    raise ArgumentError, "Domain must be auto_managed" unless domain.auto_managed?

    validate_domain_matches_zone!

    logger.info("Setting up automatic DNS for #{domain.domain_name}")

    hostname = fetch_expected_hostname
    return unless hostname

    create_dns_record(hostname)
  rescue Dns::Client::Error => e
    logger.error("Failed to create DNS record for #{domain.domain_name}: #{e.message}")
  rescue StandardError => e
    logger.error("DNS setup failed for #{domain.domain_name}: #{e.message}")
  end

  private

  def validate_domain_matches_zone!
    dns_client = Dns::Client.default
    return if domain.domain_name.end_with?(".#{dns_client.domain}")

    raise ArgumentError, "Domain #{domain.domain_name} does not match configured zone #{dns_client.domain}"
  end

  def service
    domain.service
  end

  def subdomain
    dns_client = Dns::Client.default
    domain.domain_name.chomp(".#{dns_client.domain}")
  end

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
    dns_client.create_a_record(subdomain: subdomain, ip_address: ip_address)
    logger.success("Created A record: #{domain.domain_name} -> #{ip_address}")
  end

  def create_cname_record(dns_client, target)
    dns_client.create_cname_record(subdomain: subdomain, target: target)
    logger.success("Created CNAME record: #{domain.domain_name} -> #{target}")
  end
end
