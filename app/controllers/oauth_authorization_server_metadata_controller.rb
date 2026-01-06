# frozen_string_literal: true

class OauthAuthorizationServerMetadataController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  # RFC 9728: Protected Resource Metadata
  # Describes the MCP server as a protected resource and points to authorization server(s)
  def protected_resource
    base_url = request.base_url

    render json: {
      resource: "#{base_url}/mcp",
      authorization_servers: [ base_url ]
    }
  end

  # RFC 8414: Authorization Server Metadata
  # Describes the OAuth authorization server endpoints and capabilities
  def authorization_server
    base_url = request.base_url

    render json: {
      issuer: base_url,

      # OAuth 2.0 endpoints provided by Doorkeeper
      authorization_endpoint: "#{base_url}/oauth/authorize",
      token_endpoint: "#{base_url}/oauth/token",
      revocation_endpoint: "#{base_url}/oauth/revoke",
      introspection_endpoint: "#{base_url}/oauth/introspect",

      # Grant types and response types
      grant_types_supported: %w[authorization_code client_credentials refresh_token],
      response_types_supported: [ "code" ],

      # Token endpoint authentication methods
      token_endpoint_auth_methods_supported: %w[client_secret_basic client_secret_post],

      # PKCE support (required by MCP spec)
      code_challenge_methods_supported: [ "S256" ],

      # Scopes
      scopes_supported: Doorkeeper.config.scopes.all.map(&:to_s),

      # Dynamic client registration (RFC 7591)
      registration_endpoint: oauth_register_url
    }
  end
end
