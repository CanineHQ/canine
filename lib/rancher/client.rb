# frozen_string_literal: true

require 'httparty'

module Rancher
  class Client
    class ApiKey < Struct.new(:token); end

    attr_reader :api_key, :provider_url

    include HTTParty

    default_options.update(verify: false, timeout: 10)

    class UnauthorizedError < StandardError; end
    class ConnectionError < StandardError; end
    class PermissionDeniedError < StandardError; end
    class AuthenticationError < StandardError; end
    class MissingCredentialError < StandardError; end

    def initialize(provider_url, api_key)
      @api_key = api_key
      @provider_url = provider_url.chomp("/")
    end

    def self.reachable?(provider_url)
      HTTParty.get("#{provider_url}/v3", verify: false, timeout: 5)
      true
    rescue Socket::ResolutionError, Net::ReadTimeout, Net::OpenTimeout, StandardError
      false
    end

    def authenticated?
      get("/v3/users", query: { me: true })
      true
    rescue UnauthorizedError
      false
    end

    def current_user
      response = get("/v3/users", query: { me: true })
      user_data = response["data"]&.first
      return nil unless user_data

      Rancher::Data::User.new(
        id: user_data["id"],
        username: user_data["username"],
        principal_ids: user_data["principalIds"] || []
      )
    end

    def clusters
      response = get("/v3/clusters")
      response["data"].map do |cluster_data|
        Rancher::Data::Cluster.new(
          id: cluster_data["id"],
          name: cluster_data["name"],
          state: cluster_data["state"],
          provider: cluster_data["provider"],
          kubernetes_version: cluster_data["version"]&.dig("gitVersion")
        )
      end
    end

    def cluster(id)
      cluster_data = get("/v3/clusters/#{id}")
      Rancher::Data::Cluster.new(
        id: cluster_data["id"],
        name: cluster_data["name"],
        state: cluster_data["state"],
        provider: cluster_data["provider"],
        kubernetes_version: cluster_data["version"]&.dig("gitVersion")
      )
    end

    def generate_kubeconfig(cluster_id)
      response = post("/v3/clusters/#{cluster_id}?action=generateKubeconfig")
      response["config"]
    end

    def catalogs
      response = get("/v3/catalogs")
      response["data"].map do |catalog_data|
        Rancher::Data::Catalog.new(
          id: catalog_data["id"],
          name: catalog_data["name"],
          url: catalog_data["url"],
          branch: catalog_data["branch"],
          catalog_type: catalog_data["catalogType"] || "helm"
        )
      end
    end

    def cluster_registration_tokens(cluster_id)
      response = get("/v3/clusters/#{cluster_id}/clusterregistrationtokens")
      response["data"]
    end

    def post(path, body: {})
      fetch_wrapper do
        self.class.post(
          "#{provider_url}#{path}",
          headers: headers,
          body: body.to_json
        )
      end
    rescue Socket::ResolutionError
      raise ConnectionError, "Rancher URL is not resolvable"
    rescue Net::ReadTimeout, Net::OpenTimeout
      raise ConnectionError, "Connection to Rancher timed out"
    end

    def get(path, query: {})
      fetch_wrapper do
        self.class.get("#{provider_url}#{path}", headers: headers, query: query, verify: false)
      end
    rescue Socket::ResolutionError
      raise ConnectionError, "Rancher URL is not resolvable"
    rescue Net::ReadTimeout, Net::OpenTimeout
      raise ConnectionError, "Connection to Rancher timed out"
    end

  private

    def headers
      @headers ||= {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{api_key.token}"
      }
    end

    def fetch_wrapper(&block)
      response = yield

      raise UnauthorizedError, "Unauthorized to access Rancher" if response.code == 401
      raise PermissionDeniedError, "Permission denied to access Rancher" if response.code == 403

      if response.success?
        response.parsed_response
      else
        raise "Failed to fetch from Rancher: #{response.code} #{response.body}"
      end
    end
  end
end
