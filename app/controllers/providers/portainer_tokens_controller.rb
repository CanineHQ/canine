module Providers
  class PortainerTokensController < ApplicationController
    before_action :authenticate_user!
    before_action :require_stack_manager

    def update
      token = params[:portainer_token]

      if token.blank?
        redirect_to providers_path, alert: "Please provide a Portainer API token"
        return
      end

      provider = current_user.providers.find_or_initialize_by(provider: Provider::PORTAINER_PROVIDER)
      provider.access_token = token
      provider.save!

      # Clear the cached portainer_jwt on the user
      current_user.instance_variable_set(:@portainer_jwt, nil)

      redirect_to providers_path, notice: "Portainer API token saved successfully"
    end

    def destroy
      provider = current_user.providers.find_by(provider: Provider::PORTAINER_PROVIDER)

      if provider&.destroy
        current_user.instance_variable_set(:@portainer_jwt, nil)
        redirect_to providers_path, notice: "Portainer API token removed"
      else
        redirect_to providers_path, alert: "No Portainer API token found"
      end
    end

    private

    def require_stack_manager
      stack_manager = current_account.stack_manager
      unless stack_manager&.portainer? && stack_manager.enable_role_based_access_control?
        redirect_to providers_path, alert: "This account does not require individual Portainer credentials"
      end
    end
  end
end
