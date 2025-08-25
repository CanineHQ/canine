# frozen_string_literal: true

require 'httparty'

module Portainer
  class Client
    attr_reader :jwt

    include HTTParty

    base_uri Rails.application.config.kubernetes_provider_url
    default_options.update(verify: false)

    class UnauthorizedError < StandardError; end
    class PermissionDeniedError < StandardError; end

    def initialize(jwt)
      @jwt = jwt
    end

    def get_kubernetes_config
      fetch_wrapper do
        self.class.get(
          '/api/kubernetes/config',
          headers: headers
        )
      end
    end

    def self.authenticate(auth_code, username: nil)
      response = if username.present?
        post(
          '/api/auth',
          headers: { 'Content-Type' => 'application/json' },
          body: {
            username: username,
            password: auth_code
          }.to_json
        )
      else
        post(
          '/api/auth/oauth/validate',
          headers: { 'Content-Type' => 'application/json' },
          body: { code: auth_code }.to_json
        )
      end

      response.parsed_response['jwt'] if response.success?
    end

    def get(path)
     fetch_wrapper do
        self.class.get(path, headers:)
      end
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
