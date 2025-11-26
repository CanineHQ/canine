module Accounts
  class SSOProvidersController < ApplicationController
    def show
      @sso_provider = current_account.sso_provider
      @configuration = @sso_provider&.configuration
    end

    def new
      @sso_provider = current_account.build_sso_provider
      @provider_type = params[:provider_type] || "oidc"

      if @provider_type == "ldap"
        @ldap_configuration = LDAPConfiguration.new
      else
        @oidc_configuration = OIDCConfiguration.new
      end
    end

    def create
      provider_type = params[:provider_type] || "oidc"
      configuration_params = provider_type == "ldap" ? ldap_configuration_params : oidc_configuration_params

      result = SSOProviders::Create.call(
        account: current_account,
        sso_provider_params: sso_provider_params,
        configuration_params: configuration_params,
        provider_type: provider_type
      )

      if result.success?
        redirect_to sso_provider_path, notice: "SSO provider created successfully"
      else
        @sso_provider = result.sso_provider
        @configuration = result.configuration
        @provider_type = provider_type

        if provider_type == "ldap"
          @ldap_configuration = @configuration
        else
          @oidc_configuration = @configuration
        end

        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @sso_provider = current_account.sso_provider
      redirect_to new_sso_provider_path, alert: "No SSO provider configured" unless @sso_provider
      @configuration = @sso_provider&.configuration

      if @sso_provider&.ldap?
        @ldap_configuration = @configuration
      else
        @oidc_configuration = @configuration
      end
    end

    def update
      @sso_provider = current_account.sso_provider
      configuration_params = @sso_provider.ldap? ? ldap_configuration_params : oidc_configuration_params

      result = SSOProviders::Update.call(
        sso_provider: @sso_provider,
        sso_provider_params: sso_provider_params,
        configuration_params: configuration_params
      )

      if result.success?
        redirect_to sso_provider_path, notice: "SSO provider updated successfully"
      else
        @configuration = @sso_provider.configuration

        if @sso_provider.ldap?
          @ldap_configuration = @configuration
        else
          @oidc_configuration = @configuration
        end

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

    private

    def sso_provider_params
      params.require(:sso_provider).permit(:name, :enabled)
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
        :scopes
      )
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
  end
end
