class StackManagersController < ApplicationController
  before_action :set_stack_manager

  def sync_clusters
    @stack_manager = current_account.stack_manager
    if @stack_manager.nil?
      redirect_to clusters_path, alert: "Stack manager not found"
      return
    end
    stack = @stack_manager.connect(current_user)
    stack.sync_clusters
    unless stack.provides_clusters?
      redirect_to clusters_path, alert: "This stack manager does not provide clusters"
      return
    end
    redirect_to clusters_path, notice: "Clusters synced successfully"
  end

  private

  def set_stack_manager
    @stack_manager = current_account.stack_manager
  end
end
