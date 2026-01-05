class OauthClientRegistrationController < ApplicationController
  # allow_unauthenticated_access only: [ :create ]
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  rate_limit to: 10, within: 1.hour, only: :create, with: -> { render_rejection }

  before_action :ensure_json_request, only: :create

  # RFC 7591: Dynamic Client Registration Protocol
  # Describes mechanisms for dynamically registering OAuth 2.0 clients with authorization servers
  def create
    application = Doorkeeper::Application.new(registration_params)

    if application.save
      render json: registration_response(application), status: 201
    else
      render_validation_errors(application.errors)
    end
  end

  private

  def ensure_json_request
    unless request.content_type == "application/json"
      render json: { error: "invalid_request", error_description: "Content-Type must be application/json" }, status: 400
    end
  end

  def registration_params
    params.require(:redirect_uris)

    {
      name: params[:client_name] || "MCP Client",
      redirect_uri: params[:redirect_uris].join("\n"),
      scopes: Doorkeeper.config.scopes.all.map(&:to_s),
      confidential: true
    }
  end

  def registration_response(application)
    {
      client_id: application.uid,
      client_id_issued_at: application.created_at.to_i,
      client_name: application.name,
      client_secret: application.plaintext_secret,
      client_secret_expires_at: 0,
      grant_types: [ "authorization_code" ],
      redirect_uris: application.redirect_uri.split("\n"),
      response_types: [ "code" ],
      scope: application.scopes.to_a.join(" "),
      token_endpoint_auth_method: "client_secret_post"
    }
  end

  def render_validation_errors(errors)
    error_type = errors.key?(:redirect_uri) ? "invalid_redirect_uri" : "invalid_client_metadata"
    render json: {
      error: error_type,
      error_description: errors.full_messages.join(", ")
    }, status: 400
  end

  def render_rejection
    render json: {
      error: "rate_limit_exceeded",
      error_description: "Too many registration requests"
    }, status: 429
  end
end
