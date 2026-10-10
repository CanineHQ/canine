# frozen_string_literal: true

module Tools
  class UpdateProject < MCP::Tool
    include Tools::Concerns::Authentication

    description "Update a project's settings including name, branch, build configuration, and more. Redeploy the project afterwards for changes to take effect."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        name: {
          type: "string",
          description: "Project name (lowercase letters, numbers, and hyphens only)"
        },
        repository_url: {
          type: "string",
          description: "Git repository URL"
        },
        branch: {
          type: "string",
          description: "Git branch to deploy from"
        },
        autodeploy: {
          type: "boolean",
          description: "Automatically deploy when changes are pushed to the branch"
        },
        predeploy_command: {
          type: "string",
          description: "Command to run before each deployment (e.g. 'rails db:migrate')"
        },
        image_repository: {
          type: "string",
          description: "Container image repository path (e.g. 'owner/repo')"
        },
        dockerfile_path: {
          type: "string",
          description: "Path to the Dockerfile (e.g. './Dockerfile')"
        },
        context_directory: {
          type: "string",
          description: "Docker build context directory (e.g. '.')"
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: true,
      read_only_hint: false
    )

    def self.call(project_id:, name: nil, repository_url: nil, branch: nil, autodeploy: nil,
                  predeploy_command: nil, image_repository: nil, dockerfile_path: nil,
                  context_directory: nil, server_context:)
      with_account_users(server_context: server_context) do |user, account_users|
        project = find_project(project_id, account_users)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        result = Api::Projects::Update.execute(
          project: project,
          user: user,
          params: {
            name: name.presence,
            repository_url: repository_url.presence,
            branch: branch.presence,
            autodeploy: autodeploy,
            predeploy_command: predeploy_command,
            image_repository: image_repository.presence,
            dockerfile_path: dockerfile_path.presence,
            context_directory: context_directory.presence
          }
        )

        if result.success?
          changes = result.changes.map { |k, v| "#{k}=#{v}" }

          MCP::Tool::Response.new([ {
            type: "text",
            text: "Project '#{project.name}' updated successfully (#{changes.join(', ')}). Redeploy the project for changes to take effect."
          } ])
        else
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Failed to update project: #{result.message}"
          } ], error: true)
        end
      end
    end
  end
end
