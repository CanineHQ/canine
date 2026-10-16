# frozen_string_literal: true

module Tools
  class CreateProject < MCP::Tool
    include Tools::Concerns::Authentication

    description "Create a new project and prepare it for deployment. Use list_accounts to find cluster IDs and list_providers to find provider IDs."

    input_schema(
      properties: {
        name: {
          type: "string",
          description: "Project name (lowercase letters, numbers, and hyphens only)"
        },
        repository_url: {
          type: "string",
          description: "Git repository in 'owner/repo' format (e.g. 'myorg/my-app')"
        },
        cluster_id: {
          type: "integer",
          description: "The cluster ID to deploy to (from list_accounts)"
        },
        provider_id: {
          type: "integer",
          description: "The Git provider ID (from list_providers)"
        },
        branch: {
          type: "string",
          description: "Git branch to deploy from (default: 'main')"
        },
        dockerfile_path: {
          type: "string",
          description: "Path to Dockerfile (default: './Dockerfile')"
        },
        docker_build_context_directory: {
          type: "string",
          description: "Docker build context directory (default: '.')"
        },
        predeploy_command: {
          type: "string",
          description: "Command to run before each deployment (e.g. 'rails db:migrate')"
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "name", "repository_url", "cluster_id", "provider_id" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: false,
      read_only_hint: false
    )

    def self.call(name:, repository_url:, cluster_id:, provider_id:, branch: "main",
                  dockerfile_path: "./Dockerfile", docker_build_context_directory: ".",
                  predeploy_command: nil, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |user, account_user|
        account = account_user.account

        cluster = account.clusters.find_by(id: cluster_id)
        unless cluster
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Cluster not found in this account. Use list_accounts to see available clusters."
          } ], error: true)
        end

        provider = user.providers.find_by(id: provider_id)
        unless provider
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Provider not found. Use list_providers to see available providers."
          } ], error: true)
        end

        params = ActionController::Parameters.new(
          project: {
            name: name,
            repository_url: repository_url,
            cluster_id: cluster_id,
            branch: branch,
            managed_namespace: true,
            predeploy_command: predeploy_command,
            project_credential_provider: {
              provider_id: provider_id
            },
            build_configuration: {
              dockerfile_path: dockerfile_path,
              context_directory: docker_build_context_directory
            }
          }
        )

        result = ::Projects::Create.call(params, user)

        if result.success?
          project = result.project
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Project '#{project.name}' created successfully (ID: #{project.id}). " \
                  "Use deploy_project to trigger the first deployment."
          } ])
        else
          errors = result.project&.errors&.full_messages&.join(", ") || result.message
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Failed to create project: #{errors}"
          } ], error: true)
        end
      end
    end
  end
end
