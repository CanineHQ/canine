# frozen_string_literal: true

require 'httparty'

module Rancher
  class Client
    attr_reader :api_token, :provider_url

    include HTTParty

    default_options.update(verify: false, timeout: 5)

    class UnauthorizedError < StandardError; end
    class ConnectionError < StandardError; end
    class PermissionDeniedError < StandardError; end
    class MissingCredentialError < StandardError; end

    def initialize(provider_url, api_token)
      @api_token = api_token
      @provider_url = provider_url.chomp("/")
    end

    def self.reachable?(provider_url)
      provider_url = if Rails.configuration.remap_localhost.present?
        K8::Kubeconfig.remap_localhost(provider_url)
      else
        provider_url
      end
      HTTParty.get("#{provider_url}/v3", verify: false)
      true
    rescue Socket::ResolutionError, Net::ReadTimeout, StandardError
      false
    end

    def authenticated?
      get("/v3/users?me=true")
      true
    rescue UnauthorizedError
      false
    end

    def current_user
      response = get("/v3/users?me=true")
      users = response["data"] || []
      user = users.first
      return nil unless user

      Rancher::Data::User.new(
        id: user["id"],
        username: user["username"]
      )
    end

    def clusters
      response = get("/v3/clusters")
      (response["data"] || []).map do |cluster_data|
        Rancher::Data::Cluster.new(
          id: cluster_data["id"],
          name: cluster_data["name"],
          state: cluster_data["state"]
        )
      end
    end

    def generate_kubeconfig(cluster_id)
      response = post("/v3/clusters/#{cluster_id}?action=generateKubeconfig")
      YAML.safe_load(response["config"])
    end

    def get(path, query: {})
      fetch_wrapper do
        self.class.get("#{provider_url}#{path}", headers:, query:, verify: false)
      end
    rescue Socket::ResolutionError
      raise ConnectionError, "Rancher URL is not resolvable"
    rescue Net::ReadTimeout, Net::OpenTimeout
      raise ConnectionError, "Connection to Rancher timed out"
    end

    def post(path, body: {})
      fetch_wrapper do
        self.class.post(
          "#{provider_url}#{path}",
          headers:,
          body: body.to_json
        )
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
        'Authorization' => "Bearer #{api_token}"
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
