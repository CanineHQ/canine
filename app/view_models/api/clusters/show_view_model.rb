# frozen_string_literal: true

module Api
  module Clusters
    class ShowViewModel
      def initialize(cluster)
        @cluster = cluster
      end

      def as_json
        {
          id: @cluster.id,
          name: @cluster.name,
          cluster_type: @cluster.cluster_type,
          status: @cluster.status,
          link_to_view_url: Rails.application.routes.url_helpers.cluster_path(@cluster),
          created_at: @cluster.created_at,
          updated_at: @cluster.updated_at,
          packages: @cluster.cluster_packages.map do |p|
            { id: p.id, name: p.name, status: p.status, installed_at: p.installed_at }
          end
        }
      end
    end
  end
end
