# frozen_string_literal: true

module Tools
  class UpdateBuildConfiguration < MCP::Tool
    include Tools::Concerns::Authentication

    description "Update a project's build configuration. Use this to change the image repository, Dockerfile path, or build context directory. Redeploy the project afterwards for changes to take effect."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        image_repository: {
          type: "string",
          description: "Container image repository path (e.g. 'owner/repo' or 'owner/repo/project-name')"
        },
        dockerfile_path: {
          type: "string",
          description: "Path to the Dockerfile (e.g. './Dockerfile' or 'apps/web/Dockerfile')"
        },
        context_directory: {
          type: "string",
          description: "Docker build context directory (e.g. '.' or 'apps/web')"
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: true,
      read_only_hint: false
    )

    def self.call(project_id:, image_repository: nil, dockerfile_path: nil, context_directory: nil, server_context:)
      with_account_users(server_context: server_context) do |user, account_users|
        project = find_project(project_id, account_users)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        build_config = project.build_configuration

        unless build_config
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project '#{project.name}' has no build configuration"
          } ], error: true)
        end

        build_config.image_repository = image_repository if image_repository.present?
        build_config.dockerfile_path = dockerfile_path if dockerfile_path.present?
        build_config.context_directory = context_directory if context_directory.present?

        if build_config.save
          changes = []
          changes << "image_repository=#{build_config.image_repository}" if image_repository.present?
          changes << "dockerfile_path=#{build_config.dockerfile_path}" if dockerfile_path.present?
          changes << "context_directory=#{build_config.context_directory}" if context_directory.present?

          MCP::Tool::Response.new([ {
            type: "text",
            text: "Build configuration updated for project '#{project.name}' (#{changes.join(', ')}). Redeploy the project for changes to take effect."
          } ])
        else
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Failed to update build configuration: #{build_config.errors.full_messages.join(', ')}"
          } ], error: true)
        end
      end
    end
  end
end
