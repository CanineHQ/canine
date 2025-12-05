module Accounts
  class StackManagersController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_account_admin, only: [ :show, :new, :create, :edit, :update, :destroy, :sync_clusters, :sync_registries ]
    before_action :set_stack_manager, only: [ :show, :edit, :update, :destroy, :sync_clusters, :sync_registries ]
    before_action :set_stack, only: [ :sync_clusters, :sync_registries ]
    skip_before_action :authenticate_user!, only: [ :verify_url, :check_reachable ]

    def check_reachable
      url = params[:stack_manager][:url]
      unless Portainer::Client.reachable?(url)
        head :bad_gateway
        return
      end
      head :ok
    end

    def verify_connectivity
      stack_manager = current_account.stack_manager
      if stack_manager.nil?
        head :not_found
        return
      end

      if current_user.portainer_access_token.blank?
        head :unauthorized
        return
      end

      stack = stack_manager.stack.connect(current_user, allow_anonymous: false)
      if stack.authenticated?
        head :ok
      else
        head :unauthorized
      end
    rescue Portainer::Client::MissingCredentialError, Portainer::Client::UnauthorizedError
      head :unauthorized
    rescue Portainer::Client::ConnectionError
      head :bad_gateway
    end

    def verify_url
      url = params[:stack_manager][:url]
      access_token = params[:stack_manager][:access_token]
      stack_manager = StackManager.new(
        provider_url: url,
        access_token: access_token,
      )
      unless Portainer::Client.reachable?(url)
        return head :bad_gateway
      end

      # Allow anonymous because we're checking the verify_url
      stack = stack_manager.stack.connect(nil, allow_anonymous: true)
      _verify_stack(stack)
    end

    def index
      redirect_to stack_manager_path
    end

    def show
    end

    def new
      @stack_manager = StackManager.new
    end

    def create
      @stack_manager = current_account.build_stack_manager(stack_manager_params)

      if @stack_manager.save
        redirect_to stack_manager_path, notice: "Stack manager was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      redirect_to new_stack_manager_path unless @stack_manager
    end

    def update
      if @stack_manager.update(stack_manager_params)
        redirect_to stack_manager_path, notice: "Stack manager was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @stack_manager.destroy!
      redirect_to stack_manager_path, notice: "Stack manager was successfully removed."
    end

    def sync_clusters
      @stack.sync_clusters
      unless @stack.provides_clusters?
        redirect_to clusters_path, alert: "This stack manager does not provide clusters"
        return
      end
      redirect_to clusters_path, notice: "Clusters synced successfully"
    end

    def sync_registries
      unless @stack.provides_registries?
        redirect_to providers_path, alert: "This stack manager does not provide registries"
        return
      end

      clusters = @stack.sync_clusters
      target_cluster = clusters.first
      if target_cluster.nil?
        redirect_to providers_path, alert: "No cluster found"
        return
      end

      @stack.sync_registries(current_user, target_cluster)
      redirect_to providers_path, notice: "Registries synced successfully"
    end


    private

    def stack_manager_params
      params.require(:stack_manager).permit(
        :provider_url,
        :stack_manager_type,
        :access_token,
        :enable_role_based_access_control
      )
    end

    def set_stack_manager
      @stack_manager = current_account.stack_manager
    end

    def authorize_account_admin
      authorize current_account, :manage_stack_manager?
    end

    def set_stack
      @stack ||= @stack_manager&.stack&.connect(current_user)
    end

    def _verify_stack(stack)
      if stack.authenticated?
        head :ok
      else
        head :unauthorized
      end
    end
  end
end
