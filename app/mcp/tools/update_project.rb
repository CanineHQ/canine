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

        project_attrs = {}
        project_attrs[:name] = name if name.present?
        project_attrs[:repository_url] = repository_url if repository_url.present?
        project_attrs[:branch] = branch if branch.present?
        project_attrs[:autodeploy] = autodeploy unless autodeploy.nil?
        project_attrs[:predeploy_command] = predeploy_command unless predeploy_command.nil?

        build_config_attrs = {}
        build_config_attrs[:image_repository] = image_repository if image_repository.present?
        build_config_attrs[:dockerfile_path] = dockerfile_path if dockerfile_path.present?
        build_config_attrs[:context_directory] = context_directory if context_directory.present?

        params = ActionController::Parameters.new(
          project: project_attrs.merge(
            build_configuration: build_config_attrs
          )
        )

        result = ::Projects::Update.call(project, params, user)

        if result.success?
          changes = project_attrs.except(:build_configuration).map { |k, v| "#{k}=#{v}" }
          changes += build_config_attrs.map { |k, v| "#{k}=#{v}" }

          MCP::Tool::Response.new([ {
            type: "text",
            text: "Project '#{project.reload.name}' updated successfully (#{changes.join(', ')}). Redeploy the project for changes to take effect."
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
