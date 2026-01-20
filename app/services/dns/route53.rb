class Dns::Route53 < Dns::Client
  attr_reader :access_key_id, :secret_access_key, :hosted_zone_id, :domain

  def initialize(access_key_id: nil, secret_access_key: nil, hosted_zone_id: nil, domain: nil)
    @access_key_id = access_key_id || default_access_key_id
    @secret_access_key = secret_access_key || default_secret_access_key
    @hosted_zone_id = hosted_zone_id || default_hosted_zone_id
    @domain = domain || default_domain
  end

  def create_a_record(subdomain:, ip_address:, proxied: false, ttl: 300)
    change_record(subdomain: subdomain, type: "A", value: ip_address, ttl: ttl)
  end

  def create_cname_record(subdomain:, target:, proxied: false, ttl: 300)
    change_record(subdomain: subdomain, type: "CNAME", value: target, ttl: ttl)
  end

  def delete_record(subdomain:)
    record = find_record(subdomain: subdomain)
    return false unless record

    client.change_resource_record_sets({
      hosted_zone_id: hosted_zone_id,
      change_batch: {
        changes: [ {
          action: "DELETE",
          resource_record_set: record
        } ]
      }
    })
    true
  end

  def record_exists?(subdomain:)
    find_record(subdomain: subdomain).present?
  end

  def find_record(subdomain:)
    name = build_fqdn(subdomain)
    response = client.list_resource_record_sets({
      hosted_zone_id: hosted_zone_id,
      start_record_name: name,
      max_items: 1
    })

    record = response.resource_record_sets.first
    record if record && record.name.chomp(".") == name
  end

  private

  def build_fqdn(subdomain)
    "#{subdomain}.#{domain}"
  end

  def change_record(subdomain:, type:, value:, ttl:)
    name = build_fqdn(subdomain)

    client.change_resource_record_sets({
      hosted_zone_id: hosted_zone_id,
      change_batch: {
        changes: [ {
          action: "UPSERT",
          resource_record_set: {
            name: name,
            type: type,
            ttl: ttl,
            resource_records: [ { value: value } ]
          }
        } ]
      }
    })
  end

  def client
    @client ||= Aws::Route53::Client.new(
      access_key_id: access_key_id,
      secret_access_key: secret_access_key
    )
  end

  def default_access_key_id
    ENV["AWS_ACCESS_KEY_ID"] || Rails.application.credentials.dig(:aws, :access_key_id)
  end

  def default_secret_access_key
    ENV["AWS_SECRET_ACCESS_KEY"] || Rails.application.credentials.dig(:aws, :secret_access_key)
  end

  def default_hosted_zone_id
    ENV["AWS_HOSTED_ZONE_ID"] || Rails.application.credentials.dig(:aws, :hosted_zone_id)
  end

  def default_domain
    ENV["AWS_DOMAIN"] || Rails.application.credentials.dig(:aws, :domain) || "oncanine.run"
  end
end
