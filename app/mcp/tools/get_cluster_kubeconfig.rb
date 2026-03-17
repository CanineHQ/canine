# frozen_string_literal: true

module Tools
  class GetClusterKubeconfig < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get the kubeconfig for a cluster. This is sensitive credential data — only call this when explicitly requested by the user."

    input_schema(
      properties: {
        cluster_id: {
          type: "integer",
          description: "The ID of the cluster (from canine://clusters)"
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

    def self.call(cluster_id:, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |_user, account_user|
        cluster = account_user.account.clusters.find_by(id: cluster_id)

        unless cluster
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Cluster not found or you don't have access to it"
          } ], error: true)
        end

        if cluster.kubeconfig.blank?
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "No kubeconfig available for this cluster"
          } ], error: true)
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: { cluster_id: cluster.id, name: cluster.name, kubeconfig: cluster.kubeconfig }.to_json
        } ])
      end
    end
  end
end
