# frozen_string_literal: true

module Tools
  class ScaleService < MCP::Tool
    include Tools::Concerns::Authentication

    description "Scale a service's replica count up or down. Useful for temporarily stopping a broken service (scale to 0) or handling increased load."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        service_id: {
          type: "integer",
          description: "The ID of the service to scale (use get_project_details to find service IDs)"
        },
        replicas: {
          type: "integer",
          description: "The desired number of replicas (0-20)"
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "project_id", "service_id", "replicas" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: true,
      read_only_hint: false
    )

    def self.call(project_id:, service_id:, replicas:, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
        project = projects.find_by(id: project_id)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        service = project.services.find_by(id: service_id)

        unless service
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Service not found in this project. Use get_project_details to find available services."
          } ], error: true)
        end

        replicas = [ [ replicas, 0 ].max, 20 ].min

        connection = K8::Connection.new(project, user)
        kubectl = K8::Kubectl.new(connection)
        kubectl.call("scale deployment/#{service.name} --replicas=#{replicas} -n #{project.namespace}")

        previous_replicas = service.replicas
        service.update!(replicas: replicas)

        MCP::Tool::Response.new([ {
          type: "text",
          text: "Service '#{service.name}' scaled from #{previous_replicas} to #{replicas} replicas"
        } ])
      end
    end
  end
end
