# frozen_string_literal: true

module Tools
  class ListProjects < MCP::Tool
    include Tools::Concerns::Authentication

    description "List all projects accessible to the current user"

    input_schema(
      properties: {
        account_id: {
          type: "integer",
          description: "The ID of the account to list projects for (optional, defaults to first account)"
        }
      },
      required: []
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |_user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user)
          .projects
          .order(:name)
          .limit(50)

        project_list = projects.map do |p|
          current_deployment = p.current_deployment
          Api::Projects::ShowViewModel.new(p).as_json.merge(
            last_deployment_at: p.last_deployment_at,
            current_commit_message: current_deployment&.build&.commit_message
          )
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: project_list.to_json
        } ])
      end
    end
  end
end
