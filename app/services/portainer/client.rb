# frozen_string_literal: true

require 'httparty'

module Portainer
  class Client
    include HTTParty

    base_uri Rails.application.config.kubernetes_provider_url
    default_options.update(verify: false)

    def initialize(jwt)
      @jwt = jwt
    end

    def get_kubernetes_config
      response = self.class.get(
        '/api/kubernetes/config',
        headers: {
          'Authorization' => "Bearer #{@jwt}"
        }
      )

      response.parsed_response if response.success?
    end

    def self.authenticate(user, auth_code)
      response = if user.username.present?
        post(
          '/api/auth',
          headers: { 'Content-Type' => 'application/json' },
          body: {
            username: user.username,
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
  end
end
