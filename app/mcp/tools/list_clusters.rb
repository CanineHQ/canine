# frozen_string_literal: true

module Tools
  class ListClusters < MCP::Tool
    include Tools::Concerns::Authentication

    description "List all clusters accessible to the current user"

    input_schema(
      properties: {
        account_id: {
          type: "integer",
          description: "The ID of the account to list clusters for (optional, defaults to first account)"
        }
      },
      required: []
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |_user, account_user|
        clusters = account_user.account.clusters.order(:name)

        cluster_list = clusters.map do |c|
          Api::Clusters::ShowViewModel.new(c).as_json
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: cluster_list.to_json
        } ])
      end
    end
  end
end
