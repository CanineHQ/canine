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
  end
end