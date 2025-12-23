module Accounts
  class SAMLController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :verify_authenticity_token, only: [ :callback ]
    before_action :load_account

    def authorize
      saml_configuration = @account.sso_provider&.configuration
      unless saml_configuration.is_a?(SAMLConfiguration)
        redirect_to account_sign_in_path(@account.slug), alert: "SAML is not configured for this account"
        return
      end

      authenticator = ::SAML::Authenticator.new(saml_configuration, account: @account)
      authorization_url = authenticator.authorization_url(relay_state: @account.slug)
      redirect_to authorization_url, allow_other_host: true
    end

    def callback
      saml_configuration = @account.sso_provider&.configuration

      unless saml_configuration.is_a?(SAMLConfiguration)
        redirect_to root_path, alert: "SAML is not configured"
        return
      end

      if params[:SAMLResponse].blank?
        redirect_to account_sign_in_path(@account.slug), alert: "No SAML response received"
        return
      end

      authenticator = ::SAML::Authenticator.new(saml_configuration, account: @account)
      result = authenticator.authenticate(saml_response: params[:SAMLResponse])

      unless result.success?
        redirect_to account_sign_in_path(@account.slug), alert: result.error_message
        return
      end

      # Create or find user
      sso_provider = @account.sso_provider
      ar_result = SSO::SyncUserTeams.call(
        email: result.email,
        team_names: result.groups || [],
        account: @account,
        sso_provider: sso_provider,
        uid: result.uid,
        name: result.name,
        create_teams: sso_provider.just_in_time_team_provisioning_mode?
      )

      if ar_result.failure?
        redirect_to account_sign_in_path(@account.slug), alert: "Failed to create user account"
        return
      end

      # Sign in user
      sign_in(ar_result.user)
      session[:account_id] = @account.id
      redirect_to after_sign_in_path_for(ar_result.user), notice: "Signed in successfully"
    end

    def metadata
      saml_configuration = @account.sso_provider&.configuration

      unless saml_configuration.is_a?(SAMLConfiguration)
        render plain: "SAML is not configured", status: :not_found
        return
      end

      authenticator = ::SAML::Authenticator.new(saml_configuration, account: @account)
      render xml: authenticator.metadata
    end

    private

    def load_account
      @account = Account.friendly.find(params[:slug])
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "Account not found"
    end
  end
end
