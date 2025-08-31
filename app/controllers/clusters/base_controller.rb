class Clusters::BaseController < ApplicationController
  before_action :set_cluster

  def active_connection
    @_active_connection ||= K8::Connection.new(@cluster, current_user)
  end
  helper_method :active_connection

  private

  def set_cluster
    @cluster = Cluster.find(params[:cluster_id])
  end
end
