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
      result = Api::AddOns::Search.execute(query: query)

      unless result.success?
        return MCP::Tool::Response.new([ {
          type: "text",
          text: result.message
        } ], error: true)
      end

      MCP::Tool::Response.new([ {
        type: "text",
        text: result.results.to_json
      } ])
    end
  end
end
