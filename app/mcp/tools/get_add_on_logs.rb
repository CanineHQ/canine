# frozen_string_literal: true

module Tools
  class GetAddOnLogs < MCP::Tool
    description "Get logs from all running processes for an add-on, including pod events"

    input_schema(
      properties: {
        add_on_id: {
          type: "integer",
          description: "The ID of the add-on"
        },
        tail_lines: {
          type: "integer",
          description: "Number of log lines to return per pod (default: 100, max: 500)"
        }
      },
      required: [ "add_on_id" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(add_on_id:, tail_lines: 100, server_context:)
      user = User.find(server_context[:user_id])
      account_user = user.account_users.first

      add_ons = ::AddOns::VisibleToUser.execute(account_user: account_user).add_ons
      add_on = add_ons.find_by(id: add_on_id)

      unless add_on
        return MCP::Tool::Response.new([ {
          type: "text",
          text: "Add-on not found or you don't have access to it"
        } ], is_error: true)
      end

      tail_lines = [ tail_lines, 500 ].min

      begin
        connection = K8::Connection.new(add_on.cluster, user)
        client = K8::Client.new(connection)
        pods = client.get_pods(namespace: add_on.name)

        logs_data = pods.map do |pod|
          pod_name = pod.metadata.name

          pod_logs = begin
            client.get_pod_log(pod_name, add_on.name, tail_lines: tail_lines)
          rescue Kubeclient::HttpError => e
            "Error fetching logs: #{e.message}"
          end

          pod_events = begin
            client.get_pod_events(pod_name, add_on.name).map do |event|
              {
                type: event.type,
                reason: event.reason,
                message: event.message,
                first_seen: event.firstTimestamp&.iso8601,
                last_seen: event.lastTimestamp&.iso8601,
                count: event.count
              }
            end
          rescue Kubeclient::HttpError => e
            [ { error: "Error fetching events: #{e.message}" } ]
          end

          {
            pod_name: pod_name,
            status: pod.status.phase,
            container_status: pod.status.containerStatuses&.first&.state&.to_h,
            logs: pod_logs,
            events: pod_events
          }
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: logs_data.to_json
        } ])
      rescue StandardError => e
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Error connecting to cluster: #{e.message}"
        } ], is_error: true)
      end
    end
  end
end
