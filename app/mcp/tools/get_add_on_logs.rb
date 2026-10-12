# frozen_string_literal: true

module Tools
  class GetAddOnLogs < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get logs from all running processes for an add-on, including pod events. Required param: 'add_on_id' (integer)."

    input_schema(
      properties: {
        add_on_id: {
          type: "integer",
          description: "The ID of the add-on"
        },
        tail_lines: {
          type: "integer",
          description: "Number of log lines to return per pod (default: 100, max: 500)"
        }
      },
      required: [ "add_on_id" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(add_on_id:, tail_lines: 100, server_context:)
      with_account_users(server_context: server_context) do |user, account_users|
        add_on = find_add_on(add_on_id, account_users)

        unless add_on
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Add-on not found or you don't have access to it"
          } ], error: true)
        end

        result = Api::AddOns::Logs.execute(add_on: add_on, user: user, tail_lines: tail_lines)

        if result.success?
          MCP::Tool::Response.new([ {
            type: "text",
            text: result.pods.to_json
          } ])
        else
          MCP::Tool::Response.new([ {
            type: "text",
            text: result.message
          } ], error: true)
        end
      end
    end
  end
end
