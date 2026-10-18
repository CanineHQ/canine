# frozen_string_literal: true

module Tools
  class ListAgentComputers < MCP::Tool
    include Tools::Concerns::Authentication

    description "List the agent computers (cloud desktops) you can use. Their IDs are what the computer_* tools take."

    input_schema(properties: {})

    annotations(read_only_hint: true)

    def self.call(server_context:)
      with_account_users(server_context: server_context) do |_user, account_users|
        computers = agent_computers(account_users).includes(:cluster).order(:name)
          .map { |c| { id: c.id, name: c.name, status: c.status, cluster: c.cluster.name } }

        MCP::Tool::Response.new([ { type: "text", text: computers.to_json } ])
      end
    end
  end
end
