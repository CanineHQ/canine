# frozen_string_literal: true

module Tools
  class ListAccounts < MCP::Tool
    description "List all accounts accessible to the current user and their resources (clusters, projects, add-ons). IMPORTANT: Call this tool first to discover available accounts before using other tools that require an account_id parameter."

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

      accounts = user.accounts.includes(:clusters, clusters: [ :projects, :add_ons ])

      account_list = accounts.map do |account|
        {
          id: account.id,
          name: account.name,
          slug: account.slug,
          clusters: account.clusters.map do |cluster|
            {
              id: cluster.id,
              name: cluster.name,
              cluster_type: cluster.cluster_type,
              projects_count: cluster.projects.size,
              add_ons_count: cluster.add_ons.size
            }
          end,
          totals: {
            clusters: account.clusters.size,
            projects: account.clusters.sum { |c| c.projects.size },
            add_ons: account.clusters.sum { |c| c.add_ons.size }
          }
        }
      end

      MCP::Tool::Response.new([ {
        type: "text",
        text: account_list.to_json
      } ])
    end
  end
end
