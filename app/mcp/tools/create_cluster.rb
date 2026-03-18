# frozen_string_literal: true

module Tools
  class CreateCluster < MCP::Tool
    include Tools::Concerns::Authentication

    description "Connect a Kubernetes cluster by providing its kubeconfig. Pass the kubeconfig YAML content as 'kubeconfig_yaml'. The cluster will be validated and set up with required system components."

    input_schema(
      properties: {
        name: {
          type: "string",
          description: "Cluster name (lowercase letters, numbers, and hyphens only)"
        },
        kubeconfig_yaml: {
          type: "string",
          description: "The kubeconfig YAML content for connecting to the cluster"
        },
        cluster_type: {
          type: "string",
          enum: [ "k8s", "k3s", "local_k3s" ],
          description: "Cluster type (default: 'k8s')"
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "name", "kubeconfig_yaml" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: false,
      read_only_hint: false
    )

    def self.call(name:, kubeconfig_yaml:, cluster_type: "k8s", account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |user, account_user|
        # Validate YAML before passing to the action
        begin
          YAML.safe_load(kubeconfig_yaml)
        rescue Psych::SyntaxError => e
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Invalid kubeconfig YAML: #{e.message}"
          } ], error: true)
        end

        params = ActionController::Parameters.new(
          cluster: {
            name: name,
            cluster_type: cluster_type,
            kubeconfig: kubeconfig_yaml,
            kubeconfig_yaml_format: "true"
          }
        )

        result = ::Clusters::Create.call(params, account_user)

        if result.success?
          cluster = result.cluster
          ::Clusters::InstallJob.perform_later(cluster, user)
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Cluster '#{cluster.name}' created and setup started (ID: #{cluster.id}). " \
                  "System components are being installed in the background."
          } ])
        else
          errors = result.cluster&.errors&.full_messages&.join(", ") || result.message
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Failed to create cluster: #{errors}"
          } ], error: true)
        end
      end
    end
  end
end
