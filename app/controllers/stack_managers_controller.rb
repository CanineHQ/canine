class StackManagersController < ApplicationController
  before_action :set_stack_manager

  def sync_clusters
    stack.sync_clusters
    unless stack.provides_clusters?
      redirect_to clusters_path, alert: "This stack manager does not provide clusters"
      return
    end
    redirect_to clusters_path, notice: "Clusters synced successfully"
  end

  def sync_registries
    unless stack.provides_registries?
      redirect_to providers_path, alert: "This stack manager does not provide registries"
      return
    end

    clusters = stack.sync_clusters
    target_cluster = clusters.first
    if target_cluster.nil?
      redirect_to providers_path, alert: "No cluster found"
      return
    end

    stack.sync_registries(current_user, target_cluster)
    redirect_to providers_path, notice: "Registries synced successfully"
  end

  private

  def set_stack_manager
    @stack_manager = current_account.stack_manager
    if @stack_manager.nil?
      redirect_to clusters_path, alert: "Stack manager not found"
      nil
    end
  end

  def stack
    @stack ||= @stack_manager.stack.connect(current_user)
  end
end
