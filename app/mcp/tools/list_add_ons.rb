# frozen_string_literal: true

module Tools
  class ListAddOns < MCP::Tool
    description "List all add-ons (databases, caches, etc.) accessible to the current user"

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
      account_user = user.account_users.first

      add_ons = ::AddOns::VisibleToUser.execute(account_user: account_user)
        .add_ons
        .order(:name)
        .limit(50)

      add_on_list = add_ons.map do |a|
        {
          id: a.id,
          name: a.name,
          namespace: a.namespace,
          chart_type: a.chart_type,
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
