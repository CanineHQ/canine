class Dns::Cloudflare < Dns::Client
  BASE_URL = "https://api.cloudflare.com/client/v4"
  API_TOKEN = ENV["CLOUDFLARE_API_TOKEN"]
  ZONE_ID = ENV["CLOUDFLARE_ZONE_ID"]
  DOMAIN = ENV["CLOUDFLARE_DOMAIN"] || "oncanine.run"

  attr_reader :api_token, :zone_id, :domain

  def initialize(api_token: nil, zone_id: nil, domain: nil)
    @api_token = api_token || API_TOKEN
    @zone_id = zone_id || ZONE_ID
    @domain = domain || DOMAIN
  end

  def create_a_record(subdomain:, ip_address:, proxied: false, ttl: 1)
    name = build_fqdn(subdomain)

    existing = find_record_by_name(name: name, type: "A")
    if existing
      update_record(record_id: existing["id"], type: "A", content: ip_address, proxied: proxied, ttl: ttl)
    else
      create_record(name: name, type: "A", content: ip_address, proxied: proxied, ttl: ttl)
    end
  end

  def create_cname_record(subdomain:, target:, proxied: false, ttl: 1)
    name = build_fqdn(subdomain)

    existing = find_record_by_name(name: name, type: "CNAME")
    if existing
      update_record(record_id: existing["id"], type: "CNAME", content: target, proxied: proxied, ttl: ttl)
    else
      create_record(name: name, type: "CNAME", content: target, proxied: proxied, ttl: ttl)
    end
  end

  def delete_record(subdomain:)
    name = build_fqdn(subdomain)
    record = find_record_by_name(name: name)
    return false unless record

    response = connection.delete("zones/#{zone_id}/dns_records/#{record['id']}")
    handle_response(response)
    true
  end

  def record_exists?(subdomain:)
    find_record(subdomain: subdomain).present?
  end

  def find_record(subdomain:)
    name = build_fqdn(subdomain)
    find_record_by_name(name: name)
  end

  def list_records(type: nil, name: nil)
    params = {}
    params[:type] = type if type
    params[:name] = name if name

    response = connection.get("zones/#{zone_id}/dns_records", params)
    data = handle_response(response)
    data["result"]
  end

  def list_all_records(type: nil)
    params = { per_page: 100, page: 1 }
    params[:type] = type if type

    all_records = []
    loop do
      response = connection.get("zones/#{zone_id}/dns_records", params)
      data = handle_response(response)
      all_records.concat(data["result"])

      result_info = data["result_info"]
      break if params[:page] >= result_info["total_pages"]

      params[:page] += 1
    end

    all_records
  end

  def verify_connection
    response = connection.get("user/tokens/verify")
    data = handle_response(response)
    data["success"]
  rescue Dns::Client::Error
    false
  end

  private

  def build_fqdn(subdomain)
    "#{subdomain}.#{domain}"
  end

  def find_record_by_name(name:, type: nil)
    records = list_records(name: name, type: type)
    records&.first
  end

  def create_record(name:, type:, content:, proxied:, ttl:)
    payload = {
      type: type,
      name: name,
      content: content,
      ttl: ttl,
      proxied: proxied
    }

    response = connection.post("zones/#{zone_id}/dns_records", payload.to_json)
    data = handle_response(response)
    data["result"]
  end

  def update_record(record_id:, type:, content:, proxied:, ttl:)
    payload = {
      type: type,
      content: content,
      ttl: ttl,
      proxied: proxied
    }

    response = connection.patch("zones/#{zone_id}/dns_records/#{record_id}", payload.to_json)
    data = handle_response(response)
    data["result"]
  end

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |faraday|
      faraday.headers["Authorization"] = "Bearer #{api_token}"
      faraday.headers["Content-Type"] = "application/json"
      faraday.adapter Faraday.default_adapter
    end
  end

  def handle_response(response)
    body = JSON.parse(response.body)

    unless body["success"]
      errors = body["errors"]&.map { |e| e["message"] }&.join(", ") || "Unknown error"
      raise Dns::Client::Error, errors
    end

    body
  end
end
