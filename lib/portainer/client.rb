# frozen_string_literal: true

require 'httparty'

module Portainer
  class Client
    attr_reader :jwt, :provider_url

    include HTTParty

    default_options.update(verify: false, timeout: 5)

    class UnauthorizedError < StandardError; end
    class ConnectionError < StandardError; end
    class PermissionDeniedError < StandardError; end
    class AuthenticationError < StandardError; end

    def initialize(provider_url, jwt)
      @jwt = jwt
      @provider_url = provider_url
    end

    def self.reachable?(provider_url)
      HTTParty.get("#{provider_url}/system/status")
      true
    rescue Socket::ResolutionError, Net::ReadTimeout, StandardError
      false
    end

    def authenticated?
      # TODO: This needs to be added back in.
      # response = get("/api/users/me")
      true
    rescue UnauthorizedError => e
      false
    end

    def get_kubernetes_config
      fetch_wrapper do
        self.class.get(
          "#{provider_url}/api/kubernetes/config",
          headers: headers
        )
      end
    end

    def self.authenticate(auth_code:, username: nil, provider_url:)
      response = if username.present?
        post(
          "#{provider_url}/api/auth",
          headers: { 'Content-Type' => 'application/json' },
          body: {
            username: username,
            password: auth_code
          }.to_json
        )
      else
        post(
          "#{provider_url}/api/auth/oauth/validate",
          headers: { 'Content-Type' => 'application/json' },
          body: { code: auth_code }.to_json
        )
      end

      if response.success?
        jwt = response.parsed_response['jwt']
        username_response = get(
          "#{provider_url}/api/users/me",
          headers: { 'Authorization' => "Bearer #{jwt}" },
        )

        Portainer::Data::User.new(
          id: username_response.parsed_response['Id'],
          username: username_response.parsed_response['Username'],
          jwt:
        )
      else
        raise AuthenticationError, "Invalid username or password"
      end
    rescue Socket::ResolutionError
      raise ConnectionError, "Portainer URL is not resolvable"
    rescue Net::ReadTimeout
      raise ConnectionError, "Connection to Portainer timed out"
    end

    def registries
      registries_data = get("/api/registries")
      registries_data.map do |registry_data|
        Portainer::Data::Registry.new(
          id: registry_data["Id"],
          name: registry_data["Name"],
          url: registry_data["URL"],
          username: registry_data["Username"],
          password: registry_data["Password"],
          authentication: registry_data["Authentication"]
        )
      end
    end

    def endpoints
      response = get("/api/endpoints")
      response.map do |endpoint_data|
        Portainer::Data::Endpoint.new(
          id: endpoint_data["Id"],
          name: endpoint_data["Name"],
          url: endpoint_data["URL"]
        )
      end
    end

    def get_registry_secret(registry_id, endpoint_id, kubectl)
      # Put the registry secret into the default namespace
      response = put(
        "/api/endpoints/#{endpoint_id}/registries/#{registry_id}",
        body: { namespaces: [ Clusters::Install::DEFAULT_NAMESPACE ] }
      )
      secret_name = "registry-#{registry_id}"
      secret = kubectl.call("get secret #{secret_name} -n #{Clusters::Install::DEFAULT_NAMESPACE} -o json")
      raw_secret = Base64.decode64(JSON.parse(secret)['data']['.dockerconfigjson'])
      credentials = JSON.parse(raw_secret)
      credentials
    end

    def put(path, body:)
      fetch_wrapper do
        self.class.put(
          "#{provider_url}#{path}",
          headers:,
          body: body.to_json
        )
      end
    rescue Socket::ResolutionError
      raise ConnectionError, "Portainer URL is not resolvable"
    rescue Net::ReadTimeout
      raise ConnectionError, "Connection to Portainer timed out"
    end

    def get(path)
      fetch_wrapper do
        self.class.get("#{provider_url}#{path}", headers:)
      end
    rescue Socket::ResolutionError
      raise ConnectionError, "Portainer URL is not resolvable"
    rescue Net::ReadTimeout
      raise ConnectionError, "Connection to Portainer timed out"
    end

  private

    def headers
      @headers ||= {
        'Authorization' => "Bearer #{jwt}",
        'Content-Type' => 'application/json'
      }
    end

    def fetch_wrapper(&block)
      response = yield

      raise UnauthorizedError, "Unauthorized to access Portainer" if response.code == 401
      raise PermissionDeniedError, "Permission denied to access Portainer" if response.code == 403

      if response.success?
        response.parsed_response
      else
        raise "Failed to fetch from Portainer: #{response.code} #{response.body}"
      end
    end
  end
end
