# frozen_string_literal: true

module Tools
  class CreateAddOn < MCP::Tool
    include Tools::Concerns::Authentication

    description "Install a Helm chart as an add-on (database, cache, etc.) on a cluster. Use search_add_ons to find available charts and list_accounts to find cluster IDs. Required params: 'name' (instance name), 'chart_url' (repo/chart format), 'version', 'repository_url' (Helm repo URL), 'cluster_id'."

    input_schema(
      properties: {
        name: {
          type: "string",
          description: "Add-on instance name (lowercase letters, numbers, and hyphens only, e.g. 'main-redis')"
        },
        chart_url: {
          type: "string",
          description: "Helm chart in 'repo/chart' format (e.g. 'bitnami/redis'). Use search_add_ons to find charts."
        },
        version: {
          type: "string",
          description: "Chart version to install (e.g. '18.6.1')"
        },
        repository_url: {
          type: "string",
          description: "Helm repository URL (e.g. 'https://charts.bitnami.com/bitnami')"
        },
        cluster_id: {
          type: "integer",
          description: "The cluster ID to install on (from list_accounts)"
        },
        values_yaml: {
          type: "string",
          description: "Custom Helm values as a YAML string (optional)"
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "name", "chart_url", "version", "repository_url", "cluster_id" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: false,
      read_only_hint: false
    )

    def self.call(name:, chart_url:, version:, repository_url:, cluster_id:, values_yaml: nil, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |user, account_user|
        cluster = account_user.account.clusters.find_by(id: cluster_id)
        unless cluster
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Cluster not found in this account. Use list_accounts to see available clusters."
          } ], error: true)
        end

        result = Api::AddOns::Create.execute(
          cluster: cluster,
          user: user,
          params: {
            name: name,
            chart_url: chart_url,
            version: version,
            repository_url: repository_url,
            values_yaml: values_yaml
          }
        )

        if result.success?
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Add-on '#{result.add_on.name}' created and installation started on cluster '#{cluster.name}'. " \
                  "Chart: #{chart_url} v#{version}. Add-on ID: #{result.add_on.id}"
          } ])
        else
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Failed to create add-on: #{result.message}"
          } ], error: true)
        end
      end
    end
  end
end
