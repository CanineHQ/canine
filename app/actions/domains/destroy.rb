class Domains::Destroy
  extend LightService::Action

  expects :domain

  executed do |context|
    domain = context.domain

    if domain.auto_managed? && Dns::AutoSetupService.enabled?
      cleanup_dns_record(domain)
    end

    domain.destroy!
  end

  def self.cleanup_dns_record(domain)
    dns_client = Dns::Client.default
    subdomain = domain.domain_name.chomp(".#{dns_client.domain}")
    dns_client.delete_record(subdomain: subdomain)
  rescue Dns::Client::Error => e
    Rails.logger.error("[DNS Cleanup] Failed to delete record for #{domain.domain_name}: #{e.message}")
  end
end
