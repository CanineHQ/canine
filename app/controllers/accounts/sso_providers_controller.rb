module Accounts
  class SSOProvidersController < ApplicationController
    def show
      @sso_provider = current_account.sso_provider
      @configuration = @sso_provider&.configuration
    end

    def new
      @sso_provider = current_account.build_sso_provider
      @ldap_configuration = LDAPConfiguration.new
    end

    def create
      result = SSOProviders::Create.call(
        account: current_account,
        sso_provider_params: sso_provider_params,
        configuration_params: ldap_configuration_params,
        provider_type: "ldap"
      )

      if result.success?
        redirect_to sso_provider_path, notice: "SSO provider created successfully"
      else
        @sso_provider = result.sso_provider
        @ldap_configuration = result.configuration
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @sso_provider = current_account.sso_provider
      redirect_to new_sso_provider_path, alert: "No SSO provider configured" unless @sso_provider
      @ldap_configuration = @sso_provider&.configuration
    end

    def update
      @sso_provider = current_account.sso_provider

      result = SSOProviders::Update.call(
        sso_provider: @sso_provider,
        sso_provider_params: sso_provider_params,
        configuration_params: ldap_configuration_params
      )

      if result.success?
        redirect_to sso_provider_path, notice: "SSO provider updated successfully"
      else
        @ldap_configuration = @sso_provider.configuration
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
      params.require(:sso_provider).permit(:name, :enabled, :team_provisioning_mode)
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
