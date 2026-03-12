module Clusters
  class ErrorTrackingController < ApplicationController
    before_action :set_cluster
    before_action :ensure_error_tracking_configured

    def index
      @sources = client.sources
    rescue ErrorTrackingClient::Error => e
      @error = e.message
      @sources = []
    end

    def show
      @source = find_source(params[:id].to_i)
      @events = client.events(params[:id])
    rescue ErrorTrackingClient::Error => e
      @error = e.message
      @events = []
    end

    def create
      client.create_source(name: params[:name], platform: params[:platform])
      redirect_to cluster_error_tracking_index_path(@cluster), notice: "Source created"
    rescue ErrorTrackingClient::Error => e
      redirect_to cluster_error_tracking_index_path(@cluster), alert: e.message
    end

    private

    def set_cluster
      clusters = Clusters::VisibleToUser.execute(account_user: current_account_user).clusters
      @cluster = clusters.find(params[:cluster_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to clusters_path
    end

    def ensure_error_tracking_configured
      return if @cluster.error_tracking_url.present?

      redirect_to edit_cluster_path(@cluster), alert: "Configure the error tracking URL in cluster settings first."
    end

    def client
      @client ||= ErrorTrackingClient.new(@cluster.error_tracking_url)
    end

    def find_source(id)
      client.sources.find { |s| s["id"] == id } || {}
    end
  end
end
