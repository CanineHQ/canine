# frozen_string_literal: true

Doorkeeper.configure do
  orm :active_record

  # Tokens never expire (for MCP clients)
  access_token_expires_in nil

  default_scopes :public
  optional_scopes :write, :read

  # This sometimes breaks the devise login screen,
  # but in theory should be set due to McpController inheriting from ActionController::API
  base_controller "ApplicationController"

  resource_owner_authenticator do
    current_user || warden.authenticate!(scope: :user)
  end

  # Require non-confidential clients to use PKCE when using an authorization code
  # to obtain an access_token (disabled by default)
  #
  force_pkce

  # Hash token and application secrets in the database
  # hash_token_secrets fallback: plain
  # hash_application_secrets fallback: plain

  # Allows additional data fields to be sent while granting access to an application,
  # and for this additional data to be included in subsequently generated access tokens.
  # The 'authorizations/new' page will need to be overridden to include this additional data
  # in the request params when granting access. The access grant and access token models
  # will both need to respond to these additional data fields, and have a database column
  # to store them in.
  #
  # Example:
  # You have a multi-tenanted platform and want to be able to grant access to a specific
  # tenant, rather than all the tenants a user has access to. You can use this config
  # option to specify that a ':tenant_id' will be passed when authorizing. This tenant_id
  # will be included in the access tokens. When a request is made with one of these access
  # tokens, you can check that the requested data belongs to the specified tenant.
  #
  # Default value is an empty Array: []
  # RFC 8707: Resource Indicators - store the resource parameter
  custom_access_token_attributes [ ]

  # Hook into the strategies' request & response life-cycle in case your
  # application needs advanced customization or logging:
  #
  # RFC 8707: Store resource parameter from token requests
  # after_successful_authorization do |controller, context|
  #   if controller.class == Doorkeeper::TokensController && controller.action_name == "create"
  #     token = context.auth.token
  #     token.update(resource: controller.params["resource"]) if token.resource.blank?
  #   end
  # end
end