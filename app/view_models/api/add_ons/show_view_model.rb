# frozen_string_literal: true

module Api
  module AddOns
    class ShowViewModel
      def initialize(add_on, service)
        @add_on = add_on
        @service = service
      end

      def as_json
        base = {
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
          link_to_view_url: Rails.application.routes.url_helpers.add_on_path(@add_on),
          created_at: @add_on.created_at,
          updated_at: @add_on.updated_at
        }

        base.merge(endpoints_data).merge(connection_url_data)
      end

      private

      def endpoints_data
        endpoints = @service.get_endpoints
        ingresses = @service.get_ingresses

        {
          endpoints: endpoints.map do |endpoint|
            internal_urls = endpoint.spec.ports.map do |port|
              "#{endpoint.metadata.name}.#{@add_on.name}.svc.cluster.local:#{port.port}"
            end

            external_urls = ingresses
              .select { |i| i.spec.rules.any? { |r| r.http.paths.any? { |p| p.backend.service.name == endpoint.metadata.name } } }
              .flat_map { |i| i.spec.rules.map { |r| r.host } }

            { name: endpoint.metadata.name, internal_urls: internal_urls, external_urls: external_urls }
          end
        }
      rescue StandardError => e
        { endpoints: [], endpoints_error: "Error fetching endpoints: #{e.message}" }
      end

      def connection_url_data
        return {} unless @service.respond_to?(:internal_url)

        { connection_url: @service.internal_url }
      rescue StandardError => e
        { connection_url_error: "Error fetching connection URL: #{e.message}" }
      end
    end
  end
end
