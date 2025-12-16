module Accounts
  class SSOProvidersController < ApplicationController
    def show
      @sso_provider = current_account.sso_provider
      @configuration = @sso_provider&.configuration
    end

    def new
      @provider_type = params[:provider_type] || "ldap"
      @sso_provider = current_account.build_sso_provider
      @ldap_configuration = LDAPConfiguration.new
      @oidc_configuration = OIDCConfiguration.new
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
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @sso_provider = current_account.sso_provider
      redirect_to new_sso_provider_path, alert: "No SSO provider configured" unless @sso_provider
      @provider_type = @sso_provider&.oidc? ? "oidc" : "ldap"
      @ldap_configuration = @sso_provider&.ldap? ? @sso_provider.configuration : LDAPConfiguration.new
      @oidc_configuration = @sso_provider&.oidc? ? @sso_provider.configuration : OIDCConfiguration.new
    end

    def update
      @sso_provider = current_account.sso_provider
      provider_type = @sso_provider.oidc? ? "oidc" : "ldap"

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
      else
        {}
      end
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
  end
end
