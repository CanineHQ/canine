# app/services/oidc/authenticator.rb
module OIDC
  class Authenticator
    Result = Struct.new(
      :success?,
      :email,
      :name,
      :uid,
      :groups,
      :id_token,
      :access_token,
      :error_message,
      keyword_init: true
    )

    def initialize(oidc_configuration, logger: Rails.logger)
      @config = oidc_configuration
      @logger = logger
      @discovery_cache = nil
    end

    def authenticate(code:, redirect_uri:)
      # Exchange authorization code for tokens
      token_result = exchange_code_for_tokens(code, redirect_uri)
      return token_result if token_result.failure?

      # Parse and validate ID token claims
      claims = extract_claims(token_result.id_token, token_result.access_token)
      return claims if claims.is_a?(Result) && claims.failure?

      email = claims[config.email_claim] || claims["email"]
      name = claims[config.name_claim] || claims["name"]
      uid = claims[config.uid_claim] || claims["sub"]

      if email.blank?
        return Result.new(success?: false, error_message: "Email claim not found in token")
      end

      Result.new(
        success?: true,
        email: email,
        name: name,
        uid: uid,
        groups: extract_groups(claims),
        id_token: token_result.id_token,
        access_token: token_result.access_token,
        error_message: nil
      )
    rescue => e
      @logger.error "OIDC auth: unexpected error - #{e.class}: #{e.message}"
      Result.new(success?: false, error_message: e.message)
    end

    private

    attr_reader :config, :logger

    def exchange_code_for_tokens(code, redirect_uri)
      token_endpoint = config.token_endpoint.presence || discover_endpoint("token_endpoint")

      response = HTTP.post(token_endpoint, form: {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        client_id: config.client_id,
        client_secret: config.client_secret
      })

      unless response.status.success?
        error_body = JSON.parse(response.body.to_s) rescue {}
        error_msg = error_body["error_description"] || error_body["error"] || "Token exchange failed"
        return Result.new(success?: false, error_message: error_msg)
      end

      token_data = JSON.parse(response.body.to_s)

      OpenStruct.new(
        success?: true,
        id_token: token_data["id_token"],
        access_token: token_data["access_token"],
        refresh_token: token_data["refresh_token"]
      )
    rescue HTTP::Error => e
      Result.new(success?: false, error_message: "Failed to exchange code: #{e.message}")
    end

    def extract_claims(id_token, access_token)
      if id_token.present?
        # Decode JWT without verification for now (verification should be added for production)
        # The ID token contains the user claims
        payload = decode_jwt(id_token)
        return payload if payload.is_a?(Result)
        payload
      elsif access_token.present?
        # Fallback to userinfo endpoint
        fetch_userinfo(access_token)
      else
        Result.new(success?: false, error_message: "No tokens received")
      end
    end

    def decode_jwt(token)
      # Simple JWT decode (without signature verification - should add JWKS verification for production)
      parts = token.split(".")
      return Result.new(success?: false, error_message: "Invalid JWT format") if parts.length < 2

      payload = Base64.urlsafe_decode64(parts[1] + "=" * (4 - parts[1].length % 4))
      JSON.parse(payload)
    rescue => e
      Result.new(success?: false, error_message: "Failed to decode JWT: #{e.message}")
    end

    def fetch_userinfo(access_token)
      userinfo_endpoint = config.userinfo_endpoint.presence || discover_endpoint("userinfo_endpoint")

      response = HTTP.auth("Bearer #{access_token}").get(userinfo_endpoint)

      unless response.status.success?
        return Result.new(success?: false, error_message: "Failed to fetch user info")
      end

      JSON.parse(response.body.to_s)
    rescue => e
      Result.new(success?: false, error_message: "Failed to fetch user info: #{e.message}")
    end

    def extract_groups(claims)
      # Common group claims from various OIDC providers
      groups = claims["groups"] || claims["roles"] || claims["cognito:groups"] || []
      groups = [ groups ] unless groups.is_a?(Array)
      groups.map { |g| { name: g.to_s } }
    end

    def discover_endpoint(endpoint_name)
      discovery_doc[endpoint_name]
    end

    def discovery_doc
      return @discovery_cache if @discovery_cache

      response = HTTP.get(config.discovery_url)
      raise "Failed to fetch OIDC discovery document" unless response.status.success?

      @discovery_cache = JSON.parse(response.body.to_s)
    end
  end
end
