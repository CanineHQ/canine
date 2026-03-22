# frozen_string_literal: true

module Api
  module AddOns
    class ListViewModel
      def initialize(add_ons)
        @add_ons = add_ons
      end

      def as_json
        @add_ons.map { |add_on| serialize(add_on) }
      end

      private

      def serialize(add_on)
        {
          id: add_on.id,
          name: add_on.name,
          namespace: add_on.namespace,
          chart_url: add_on.chart_url,
          chart_type: add_on.chart_type,
          version: add_on.version,
          status: add_on.status,
          install_stage: add_on.install_stage,
          cluster_id: add_on.cluster_id,
          cluster_name: add_on.cluster.name,
          link_to_view_url: Rails.application.routes.url_helpers.add_on_path(add_on),
          created_at: add_on.created_at,
          updated_at: add_on.updated_at
        }
      end
    end
  end
end
