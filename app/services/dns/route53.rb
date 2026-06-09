class Dns::Route53 < Dns::Client
  HOSTED_ZONE_ID = ENV["ROUTE53_HOSTED_ZONE_ID"]
  DOMAIN = ENV["ROUTE53_DOMAIN"]

  attr_reader :hosted_zone_id, :domain

  def initialize(hosted_zone_id: nil, domain: nil)
    @hosted_zone_id = hosted_zone_id || HOSTED_ZONE_ID
    @domain = domain || DOMAIN
  end

  def create_a_record(subdomain:, ip_address:, proxied: false, ttl: 300)
    change_record(
      action: "UPSERT",
      name: build_fqdn(subdomain),
      type: "A",
      ttl: ttl,
      value: ip_address
    )
  end

  def create_cname_record(subdomain:, target:, proxied: false, ttl: 300)
    change_record(
      action: "UPSERT",
      name: build_fqdn(subdomain),
      type: "CNAME",
      ttl: ttl,
      value: target
    )
  end

  def delete_record(subdomain:)
    record = find_record(subdomain: subdomain)
    return false unless record

    change_record(
      action: "DELETE",
      name: record[:name],
      type: record[:type],
      ttl: record[:ttl],
      value: record[:value]
    )
    true
  end

  def record_exists?(subdomain:)
    find_record(subdomain: subdomain).present?
  end

  def find_record(subdomain:)
    fqdn = "#{build_fqdn(subdomain)}."
    resp = client.list_resource_record_sets(
      hosted_zone_id: hosted_zone_id,
      start_record_name: fqdn,
      max_items: 1
    )

    record_set = resp.resource_record_sets.first
    return nil unless record_set && record_set.name == fqdn

    {
      name: record_set.name.chomp("."),
      type: record_set.type,
      ttl: record_set.ttl,
      value: record_set.resource_records.first&.value
    }
  end

  def list_records(type: nil, name: nil)
    records = []
    params = { hosted_zone_id: hosted_zone_id }

    loop do
      resp = client.list_resource_record_sets(**params)
      resp.resource_record_sets.each do |rs|
        next if type && rs.type != type
        next if name && rs.name.chomp(".") != name

        rs.resource_records.each do |rr|
          records << {
            "name" => rs.name.chomp("."),
            "type" => rs.type,
            "ttl" => rs.ttl,
            "content" => rr.value
          }
        end
      end

      break unless resp.is_truncated

      params[:start_record_name] = resp.next_record_name
      params[:start_record_type] = resp.next_record_type
    end

    records
  end

  def list_all_records(type: nil)
    list_records(type: type)
  end

  def verify_connection
    client.get_hosted_zone(id: hosted_zone_id)
    true
  rescue StandardError
    false
  end

  private

  def build_fqdn(subdomain)
    "#{subdomain}.#{domain}"
  end

  def change_record(action:, name:, type:, ttl:, value:)
    client.change_resource_record_sets(
      hosted_zone_id: hosted_zone_id,
      change_batch: {
        changes: [
          {
            action: action,
            resource_record_set: {
              name: name,
              type: type,
              ttl: ttl,
              resource_records: [ { value: value } ]
            }
          }
        ]
      }
    )
  rescue Aws::Route53::Errors::ServiceError => e
    raise Dns::Client::Error, e.message
  end

  def client
    @client ||= Aws::Route53::Client.new
  end
end
