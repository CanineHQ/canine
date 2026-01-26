class Scheduled::SweepDnsRecordsJob < ApplicationJob
  queue_as :default

  def perform
    return unless Dns::AutoSetupService.enabled?

    dns_client = Dns::Client.default
    valid_domains = Set.new
    Domain.where(auto_managed: true).find_each { |d| valid_domains << d.domain_name }

    dns_client.list_all_records.each do |record|
      next unless stale_record?(record, valid_domains, dns_client.domain)

      Rails.logger.info("[DNS Sweep] Deleting stale record: #{record['name']}")
      delete_record(dns_client, record)
    end
  end

  private

  def stale_record?(record, valid_domains, base_domain)
    return false unless record["name"].end_with?(".#{base_domain}")
    return false if valid_domains.include?(record["name"])

    # Only sweep A and CNAME records that match the auto-managed pattern
    return false unless %w[A CNAME].include?(record["type"])

    subdomain = record["name"].chomp(".#{base_domain}")
    subdomain.match?(/\A[a-z0-9-]+-[a-z0-9-]+\z/)
  end

  def delete_record(dns_client, record)
    subdomain = record["name"].chomp(".#{dns_client.domain}")
    dns_client.delete_record(subdomain: subdomain)
  rescue Dns::Client::Error => e
    Rails.logger.error("[DNS Sweep] Failed to delete #{record['name']}: #{e.message}")
  end
end
