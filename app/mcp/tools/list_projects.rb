# frozen_string_literal: true

module Tools
  class ListProjects < MCP::Tool
    description "List all projects accessible to the current user"

    input_schema(
      properties: {},
      required: []
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(server_context:)
      user = User.find(server_context[:user_id])
      account_user = user.account_users.first

      projects = ::Projects::VisibleToUser.execute(account_user: account_user)
        .projects
        .order(:name)
        .limit(50)

      project_list = projects.map do |p|
        current_deployment = p.current_deployment
        {
          id: p.id,
          name: p.name,
          namespace: p.namespace,
          branch: p.branch,
          status: p.status,
          cluster: p.cluster.name,
          repository_url: p.repository_url,
          last_deployment_at: p.last_deployment_at&.iso8601,
          current_commit_message: current_deployment&.build&.commit_message
        }
      end

      MCP::Tool::Response.new([ {
        type: "text",
        text: project_list.to_json
      } ])
    end
  end
end
