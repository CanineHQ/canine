module Accounts
  class StackManagersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_stack, only: [ :sync_clusters, :sync_registries ]
    skip_before_action :authenticate_user!, only: [ :verify_url, :check_reachable ]

    def _verify_stack(stack)
      if stack.authenticated?
        head :ok
      else
        head :unauthorized
      end
    end

    def verify_login
      stack_manager = current_account.stack_manager
      if stack_manager.nil?
        head :not_found
      end

      # If the user is not having an email domain end in the
      # portainer stack url, don't log them out, just return a different unauthorized.
      if !stack_manager.is_user?(current_user)
        head :method_not_allowed
        return
      end

      stack = stack_manager.stack.connect(current_user, allow_anonymous: false)
      _verify_stack(stack)
    end

    def check_reachable
      url = params[:stack_manager][:url]
      unless Portainer::Client.reachable?(url)
        head :bad_gateway
        return
      end
      head :ok
    end

    def verify_url
      url = params[:stack_manager][:url]
      access_code = params[:stack_manager][:access_code]
      stack_manager = StackManager.new(
        provider_url: url,
        access_token: access_code,
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
      @stack_manager = current_account.stack_manager
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
      @stack_manager = current_account.stack_manager
      redirect_to new_stack_manager_path unless @stack_manager
    end

    def update
      @stack_manager = current_account.stack_manager

      if @stack_manager.update(stack_manager_params)
        redirect_to stack_manager_path, notice: "Stack manager was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @stack_manager = current_account.stack_manager
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

    def set_stack
      @stack ||= current_account.stack_manager&.stack&.connect(current_user)
    end
  end
end
