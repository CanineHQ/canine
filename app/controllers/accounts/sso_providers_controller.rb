module Accounts
  class SSOProvidersController < ApplicationController
    def show
      @sso_provider = current_account.sso_provider
      @oidc_configuration = @sso_provider&.configuration
    end

    def new
      @sso_provider = current_account.build_sso_provider
      @oidc_configuration = OIDCConfiguration.new
    end

    def create
      @oidc_configuration = OIDCConfiguration.new(oidc_configuration_params)
      @sso_provider = current_account.build_sso_provider(sso_provider_params)
      @sso_provider.configuration = @oidc_configuration

      if @oidc_configuration.save && @sso_provider.save
        redirect_to sso_provider_path, notice: "SSO provider created successfully"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @sso_provider = current_account.sso_provider
      redirect_to new_sso_provider_path, alert: "No SSO provider configured" unless @sso_provider
      @oidc_configuration = @sso_provider&.configuration
    end

    def update
      @sso_provider = current_account.sso_provider
      @oidc_configuration = @sso_provider.configuration

      if @oidc_configuration.update(oidc_configuration_params) && @sso_provider.update(sso_provider_params)
        redirect_to sso_provider_path, notice: "SSO provider updated successfully"
      else
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
  end
end
