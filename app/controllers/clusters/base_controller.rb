class Clusters::BaseController < ApplicationController
  before_action :set_cluster

  private

  def set_cluster
    @cluster = Cluster.find(params[:cluster_id])
  end
end