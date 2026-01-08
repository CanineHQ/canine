module Accounts
  class SSOProvidersController < ApplicationController
    before_action :authorize_account

    def show
      @sso_provider = current_account.sso_provider
      @configuration = @sso_provider&.configuration
    end

    def new
      @provider_type = params[:provider_type] || "ldap"
      @sso_provider = current_account.build_sso_provider
      @ldap_configuration = LDAPConfiguration.new
      @oidc_configuration = OIDCConfiguration.new
      @saml_configuration = SAMLConfiguration.new
    end

    def create
      provider_type = params[:provider_type] || "ldap"

      result = SSOProviders::Create.call(
        account: current_account,
        sso_provider_params: sso_provider_params,
        configuration_params: configuration_params_for(provider_type),
        provider_type: provider_type
      )

      if result.success?
        redirect_to sso_provider_path, notice: "SSO provider created successfully"
      else
        @provider_type = provider_type
        @sso_provider = result.sso_provider
        @ldap_configuration = provider_type == "ldap" ? result.configuration : LDAPConfiguration.new
        @oidc_configuration = provider_type == "oidc" ? result.configuration : OIDCConfiguration.new
        @saml_configuration = provider_type == "saml" ? result.configuration : SAMLConfiguration.new
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @sso_provider = current_account.sso_provider
      redirect_to new_sso_provider_path, alert: "No SSO provider configured" unless @sso_provider
      @provider_type = provider_type_for(@sso_provider)
      @ldap_configuration = @sso_provider&.ldap? ? @sso_provider.configuration : LDAPConfiguration.new
      @oidc_configuration = @sso_provider&.oidc? ? @sso_provider.configuration : OIDCConfiguration.new
      @saml_configuration = @sso_provider&.saml? ? @sso_provider.configuration : SAMLConfiguration.new
    end

    def update
      @sso_provider = current_account.sso_provider
      provider_type = provider_type_for(@sso_provider)

      result = SSOProviders::Update.call(
        sso_provider: @sso_provider,
        sso_provider_params: sso_provider_params,
        configuration_params: configuration_params_for(provider_type)
      )

      if result.success?
        redirect_to sso_provider_path, notice: "SSO provider updated successfully"
      else
        @provider_type = provider_type
        @ldap_configuration = @sso_provider.ldap? ? @sso_provider.configuration : LDAPConfiguration.new
        @oidc_configuration = @sso_provider.oidc? ? @sso_provider.configuration : OIDCConfiguration.new
        @saml_configuration = @sso_provider.saml? ? @sso_provider.configuration : SAMLConfiguration.new
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @sso_provider = current_account.sso_provider

      if @sso_provider&.destroy
        redirect_to sso_provider_path, notice: "SSO provider deleted"
      else
        redirect_to sso_provider_path, alert: "Failed to delete SSO provider"
      end
    end

    def test_connection
      ldap_configuration = LDAPConfiguration.new(ldap_configuration_params)
      result = LDAP::Authenticator.new(ldap_configuration).test_connection

      if result.success?
        render turbo_stream: turbo_stream.replace(
          "ldap_test_connection_result",
          partial: "accounts/sso_providers/ldap/connection_success"
        )
      else
        render turbo_stream: turbo_stream.replace(
          "ldap_test_connection_result",
          partial: "accounts/sso_providers/ldap/connection_failed",
          locals: { error_message: result.error_message }
        )
      end
    end

    private

    def sso_provider_params
      params.require(:sso_provider).permit(:name, :enabled, :team_provisioning_mode)
    end

    def configuration_params_for(provider_type)
      case provider_type
      when "ldap"
        ldap_configuration_params
      when "oidc"
        oidc_configuration_params
      when "saml"
        saml_configuration_params
      else
        {}
      end
    end

    def provider_type_for(sso_provider)
      return "ldap" if sso_provider&.ldap?
      return "oidc" if sso_provider&.oidc?
      return "saml" if sso_provider&.saml?
      "ldap"
    end

    def ldap_configuration_params
      params.require(:ldap_configuration).permit(
        :host,
        :port,
        :base_dn,
        :bind_dn,
        :bind_password,
        :uid_attribute,
        :email_attribute,
        :name_attribute,
        :filter,
        :encryption
      )
    end

    def oidc_configuration_params
      params.require(:oidc_configuration).permit(
        :issuer,
        :client_id,
        :client_secret,
        :authorization_endpoint,
        :token_endpoint,
        :userinfo_endpoint,
        :jwks_uri,
        :scopes,
        :uid_claim,
        :email_claim,
        :name_claim
      )
    end

    def saml_configuration_params
      params.require(:saml_configuration).permit(
        :idp_entity_id,
        :idp_sso_service_url,
        :idp_cert,
        :idp_slo_service_url,
        :name_identifier_format,
        :uid_attribute,
        :email_attribute,
        :name_attribute,
        :groups_attribute,
        :sp_entity_id,
        :authn_requests_signed,
        :want_assertions_signed
      )
    end

    def authorize_account
      authorize current_account, :update?
    end
  end
end
