# frozen_string_literal: true

module Tools
  class DeployProjectFork < MCP::Tool
    include Tools::Concerns::Authentication

    description "Deploy a project fork from a pull/merge request. Creates a temporary environment running the PR branch for testing."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the parent project to fork from"
        },
        pr_number: {
          type: "integer",
          description: "The pull request or merge request number"
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "project_id", "pr_number" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: false,
      read_only_hint: false
    )

    def self.call(project_id:, pr_number:, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
        project = projects.find_by(id: project_id)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        client = Git::Client.from_project(project)
        pull_request = client.pull_request(pr_number)

        unless pull_request
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Pull request ##{pr_number} not found in the project's repository"
          } ], error: true)
        end

        existing_fork = project.forks.joins(:child_project).find_by(number: pr_number)
        if existing_fork
          # Fork already exists - redeploy it
          result = ::Projects::DeployLatestCommit.execute(
            project: existing_fork.child_project,
            current_user: user,
            skip_build: false
          )

          if result.success?
            return MCP::Tool::Response.new([ {
              type: "text",
              text: "Fork for PR ##{pr_number} already exists. Redeployment started for '#{existing_fork.child_project.name}'. Build ID: #{result.build.id}"
            } ])
          else
            return MCP::Tool::Response.new([ {
              type: "text",
              text: "Fork exists but failed to redeploy: #{result.message}"
            } ], error: true)
          end
        end

        result = ::ProjectForks::Create.call(
          parent_project: project,
          pull_request: pull_request
        )

        if result.success?
          fork_project = result.project
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Fork created and deploying for PR ##{pr_number} '#{pull_request.title}'. Fork project: '#{fork_project.name}' (ID: #{fork_project.id})"
          } ])
        else
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Failed to create fork: #{result.message}"
          } ], error: true)
        end
      end
    end
  end
end
