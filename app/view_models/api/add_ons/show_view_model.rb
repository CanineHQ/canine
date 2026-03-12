# frozen_string_literal: true

module Api
  module AddOns
    class ShowViewModel
      def initialize(add_on)
        @add_on = add_on
      end

      def as_json
        {
          id: @add_on.id,
          name: @add_on.name,
          namespace: @add_on.namespace,
          chart_url: @add_on.chart_url,
          chart_type: @add_on.chart_type,
          repository_url: @add_on.repository_url,
          version: @add_on.version,
          status: @add_on.status,
          install_stage: @add_on.install_stage,
          cluster_id: @add_on.cluster_id,
          cluster_name: @add_on.cluster.name,
          created_at: @add_on.created_at,
          updated_at: @add_on.updated_at
        }
      end
    end
  end
end
