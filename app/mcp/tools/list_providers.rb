# frozen_string_literal: true

module Tools
  class ListProviders < MCP::Tool
    include Tools::Concerns::Authentication

    description "List all Git and registry providers configured for the current user. Provider IDs are needed when creating projects."

    input_schema(
      properties: {},
      required: []
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(server_context:)
      user = User.find(server_context[:user_id])

      providers = user.providers.map do |p|
        {
          id: p.id,
          type: p.provider,
          username: p.username,
          git: p.git?,
          has_native_registry: p.has_native_container_registry?,
          enterprise: p.enterprise?
        }
      end

      MCP::Tool::Response.new([ {
        type: "text",
        text: providers.to_json
      } ])
    end
  end
end
