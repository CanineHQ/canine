module Accounts
  class OIDCController < ApplicationController
    skip_before_action :authenticate_user!
    before_action :load_account

    def authorize
      oidc_config = @account.sso_provider&.configuration
      unless oidc_config.is_a?(OIDCConfiguration)
        redirect_to account_sign_in_path(@account.slug), alert: "OIDC is not configured for this account"
        return
      end

      # Store state in session for CSRF protection
      state = SecureRandom.hex(32)
      session[:oidc_state] = state

      # Build authorization URL
      auth_url = build_authorization_url(oidc_config, state)
      redirect_to auth_url, allow_other_host: true
    end

    def callback
      # Verify state for CSRF protection
      unless params[:state].present? && params[:state] == session[:oidc_state]
        redirect_to root_path, alert: "Invalid state parameter"
        return
      end

      oidc_config = @account.sso_provider&.configuration

      unless oidc_config.is_a?(OIDCConfiguration)
        redirect_to root_path, alert: "OIDC is not configured"
        return
      end

      if params[:error].present?
        redirect_to account_sign_in_path(@account.slug), alert: "Authentication failed: #{params[:error_description] || params[:error]}"
        return
      end

      # Exchange code for tokens
      result = OIDC::Authenticator.new(oidc_config).authenticate(
        code: params[:code],
        redirect_uri: oidc_callback_url(slug: @account.slug)
      )

      unless result.success?
        redirect_to account_sign_in_path(@account.slug), alert: result.error_message
        return
      end

      # Create or find user
      sso_provider = @account.sso_provider
      if sso_provider.just_in_time_team_provisioning_mode?
        ar_result = ActiveRecord::Base.transaction do
          SSO::SyncUserTeams.call(result.email, result.groups || [], @account)
        end
      else
        ar_result = SSO::CreateUserInAccount.execute(
          email: result.email,
          account: @account
        )
      end

      if ar_result.failure?
        redirect_to account_sign_in_path(@account.slug), alert: "Failed to create user account"
        return
      end

      # Clear session state
      session.delete(:oidc_state)

      # Sign in user
      sign_in(ar_result.user)
      session[:account_id] = @account.id
      redirect_to after_sign_in_path_for(ar_result.user), notice: "Signed in successfully"
    end

    private

    def load_account
      @account = Account.friendly.find(params[:slug])
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "Account not found"
    end

    def build_authorization_url(oidc_config, state)
      params = {
        response_type: "code",
        client_id: oidc_config.client_id,
        redirect_uri: oidc_callback_url(slug: @account.slug),
        scope: oidc_config.scopes,
        state: state
      }

      auth_endpoint = oidc_config.authorization_endpoint.presence || discover_authorization_endpoint(oidc_config)
      "#{auth_endpoint}?#{params.to_query}"
    end

    def discover_authorization_endpoint(oidc_config)
      # Fetch from OIDC discovery document
      discovery_url = oidc_config.discovery_url
      response = HTTP.get(discovery_url)
      if response.status.success?
        JSON.parse(response.body.to_s)["authorization_endpoint"]
      else
        raise "Failed to discover OIDC endpoints"
      end
    end
  end
end
