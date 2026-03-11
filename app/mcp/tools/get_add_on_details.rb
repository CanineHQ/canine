# frozen_string_literal: true

module Tools
  class GetAddOnDetails < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get detailed information about an add-on including its configuration, status, Helm values, and running processes"

    input_schema(
      properties: {
        add_on_id: {
          type: "integer",
          description: "The ID of the add-on"
        },
        include_values: {
          type: "boolean",
          description: "Include Helm chart values in the response (default: false)"
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "add_on_id" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(add_on_id:, include_values: false, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |user, account_user|
        add_ons = ::AddOns::VisibleToUser.execute(account_user: account_user).add_ons
        add_on = add_ons.find_by(id: add_on_id)

        unless add_on
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Add-on not found or you don't have access to it"
          } ], error: true)
        end

        details = {
          id: add_on.id,
          name: add_on.name,
          namespace: add_on.namespace,
          chart_url: add_on.chart_url,
          chart_type: add_on.chart_type,
          repository_url: add_on.repository_url,
          version: add_on.version,
          status: add_on.status,
          install_stage: add_on.install_stage,
          cluster: {
            id: add_on.cluster.id,
            name: add_on.cluster.name
          },
          created_at: add_on.created_at.iso8601,
          updated_at: add_on.updated_at.iso8601
        }

        if include_values
          begin
            connection = K8::Connection.new(add_on.cluster, user)
            helm = K8::Helm::Client.connect(connection, Cli::RunAndLog.new(add_on))
            details[:values] = helm.get_values_yaml(add_on.name, namespace: add_on.namespace)
          rescue StandardError => e
            details[:values] = "Error fetching values: #{e.message}"
          end
        end

        begin
          connection = K8::Connection.new(add_on.cluster, user)
          client = K8::Client.new(connection)
          pods = client.get_pods(namespace: add_on.name)

          details[:processes] = pods.map do |pod|
            {
              pod_name: pod.metadata.name,
              status: pod.status.phase,
              container_status: pod.status.containerStatuses&.first&.state&.to_h,
              restart_count: pod.status.containerStatuses&.first&.restartCount
            }
          end
        rescue StandardError => e
          details[:processes] = []
          details[:processes_error] = "Error fetching processes: #{e.message}"
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: details.to_json
        } ])
      end
    end
  end
end
