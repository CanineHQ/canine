# frozen_string_literal: true

module Tools
  class ListAddOns < MCP::Tool
    include Tools::Concerns::Authentication

    description "List all add-ons (databases, caches, etc.) accessible to the current user"

    input_schema(
      properties: {
        account_id: {
          type: "integer",
          description: "The ID of the account to list add-ons for (optional, defaults to first account)"
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
        add_ons = ::AddOns::VisibleToUser.execute(account_user: account_user)
          .add_ons
          .order(:name)
          .limit(50)

        add_on_list = add_ons.map do |a|
          {
            id: a.id,
            name: a.name,
            namespace: a.namespace,
            chart_url: a.chart_url,
            version: a.version,
            status: a.status,
            cluster: a.cluster.name
          }
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: add_on_list.to_json
        } ])
      end
    end
  end
end
