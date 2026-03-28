# frozen_string_literal: true

module Tools
  class SearchAddOns < MCP::Tool
    description "Search for available Helm charts on Artifact Hub to install as add-ons. Returns chart names, versions, and repository URLs needed for create_add_on."

    input_schema(
      properties: {
        query: {
          type: "string",
          description: "Search query (e.g. 'redis', 'postgresql', 'mongodb')"
        }
      },
      required: [ "query" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(query:, server_context:)
      result = ::AddOns::HelmChartSearch.execute(query: query)

      unless result.success?
        return MCP::Tool::Response.new([ {
          type: "text",
          text: "Failed to search Artifact Hub"
        } ], error: true)
      end

      # Include curated charts that match the query
      curated = K8::Helm::Client::CHARTS["helm"]["charts"].select do |c|
        c["name"].include?(query.downcase) || c["display_name"]&.downcase&.include?(query.downcase)
      end.map do |c|
        Api::HelmCharts::CuratedViewModel.new(c).as_json
      end

      # Parse Artifact Hub results
      hub_results = (result.response&.fetch("packages", nil) || []).first(15).map do |pkg|
        Api::HelmCharts::HubResultViewModel.new(pkg).as_json
      end

      MCP::Tool::Response.new([ {
        type: "text",
        text: { curated: curated, artifact_hub: hub_results }.to_json
      } ])
    end
  end
end
