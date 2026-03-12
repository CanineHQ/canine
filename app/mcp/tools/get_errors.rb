# frozen_string_literal: true

module Tools
  class GetErrors < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get recent errors from a cluster's error tracking service. Returns errors from a specific source or lists available sources if no source_id is provided."

    input_schema(
      properties: {
        cluster_id: {
          type: "integer",
          description: "The ID of the cluster to get errors from"
        },
        source_id: {
          type: "integer",
          description: "The ID of the error source (optional, omit to list available sources)"
        },
        limit: {
          type: "integer",
          description: "Number of errors to return (default: 50, max: 200)"
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "cluster_id" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(cluster_id:, source_id: nil, limit: 50, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |_user, account_user|
        clusters = Clusters::VisibleToUser.execute(account_user: account_user).clusters
        cluster = clusters.find_by(id: cluster_id)

        unless cluster
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Cluster not found or you don't have access to it"
          } ], is_error: true)
        end

        unless cluster.error_tracking_url.present?
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Error tracking is not configured for this cluster. Install the error-tracking package from cluster settings."
          } ], is_error: true)
        end

        client = ErrorTrackingClient.new(cluster.error_tracking_url)

        if source_id
          limit = [ limit, 200 ].min
          events = client.events(source_id, limit: limit)
          MCP::Tool::Response.new([ { type: "text", text: events.to_json } ])
        else
          sources = client.sources
          MCP::Tool::Response.new([ { type: "text", text: sources.to_json } ])
        end
      rescue ErrorTrackingClient::Error => e
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Error connecting to error tracking service: #{e.message}"
        } ], is_error: true)
      end
    end
  end
end
