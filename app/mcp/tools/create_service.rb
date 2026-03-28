# frozen_string_literal: true

module Tools
  class CreateService < MCP::Tool
    include Tools::Concerns::Authentication

    description "Create a new service for a project. Services define how the application runs (web, background, or cron). Changes take effect on the next deploy."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        name: {
          type: "string",
          description: "Service name (lowercase letters, numbers, and hyphens only)"
        },
        service_type: {
          type: "string",
          enum: [ "web_service", "background_service", "cron_job" ],
          description: "Type of service"
        },
        container_port: {
          type: "integer",
          description: "Port the container listens on (default: 3000, web_service only)"
        },
        replicas: {
          type: "integer",
          description: "Number of replicas to run (default: 1)"
        },
        command: {
          type: "string",
          description: "Command to run (required for cron_job, e.g. 'rails send_emails')"
        },
        healthcheck_url: {
          type: "string",
          description: "HTTP path for health checks (e.g. '/health')"
        },
        allow_public_networking: {
          type: "boolean",
          description: "Expose service to the internet via auto-managed domain (web_service only)"
        },
        cron_schedule: {
          type: "string",
          description: "Cron expression for cron_job services (e.g. '0 * * * *')"
        }
      },
      required: [ "project_id", "name", "service_type" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: false,
      read_only_hint: false
    )

    def self.call(project_id:, name:, service_type:, container_port: 3000, replicas: 1,
                  command: nil, healthcheck_url: nil, allow_public_networking: false,
                  cron_schedule: nil, server_context:)
      with_account_users(server_context: server_context) do |_user, account_users|
        project = find_project(project_id, account_users)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        service_attrs = {
          name: name,
          service_type: service_type,
          container_port: container_port,
          replicas: replicas,
          command: command,
          healthcheck_url: healthcheck_url,
          allow_public_networking: allow_public_networking
        }

        params = ActionController::Parameters.new(service: service_attrs)

        if cron_schedule.present?
          params[:service][:cron_schedule] = { schedule: cron_schedule }
        end

        service = project.services.build(Service.permitted_params(params))
        result = ::Services::Create.call(service, params)

        if result.success?
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Service '#{service.name}' created for project '#{project.name}' (ID: #{service.id}). Deploy the project for changes to take effect."
          } ])
        else
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Failed to create service: #{service.errors.full_messages.join(", ").presence || result.message}"
          } ], error: true)
        end
      end
    end
  end
end
