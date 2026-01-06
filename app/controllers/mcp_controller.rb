class MCPController < ActionController::API
  before_action :doorkeeper_authorize!

  def handle
    if params[:method] == "notifications/initialized"
      head(:accepted) and return
    end

    render(json: mcp_server.handle_json(request.body.read))
  end

  private

  def mcp_server
    server = MCP::Server.new(
      name: "canine_mcp_server",
      version: "1.0.0",
      tools: mcp_tools,
      resources: mcp_resources,
      resource_templates: mcp_resource_templates,
      server_context: { token: doorkeeper_token, user_id: doorkeeper_token.resource_owner_id }
    )

    server.resources_read_handler do |params, server_context:|
      handle_resource_read(params[:uri], server_context)
    end

    server
  end

  def mcp_tools
    [
      Tools::ListAccounts,
      Tools::ListProjects,
      Tools::GetProjectDetails,
      Tools::GetProjectLogs,
      Tools::CheckBuildStatus,
      Tools::DeployProject,
      Tools::ListAddOns,
      Tools::GetAddOnLogs
    ]
  end

  def mcp_resources
    [
      MCP::Resource.new(
        uri: "canine://projects",
        name: "projects",
        description: "List all projects accessible to the current user",
        mime_type: "application/json"
      )
    ]
  end

  def mcp_resource_templates
    [
      MCP::ResourceTemplate.new(
        uri_template: "canine://projects/{project_id}/builds",
        name: "project-builds",
        description: "List builds for a specific project",
        mime_type: "application/json"
      )
    ]
  end

  def handle_resource_read(uri, server_context)
    user = User.find(server_context[:user_id])
    account_user = user.account_users.first

    case uri
    when "canine://projects"
      projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects.order(:name).limit(50)
      [ {
        uri: uri,
        mimeType: "application/json",
        text: projects.map { |p|
          {
            id: p.id,
            name: p.name,
            namespace: p.namespace,
            branch: p.branch,
            status: p.status,
            cluster: p.cluster.name,
            repository_url: p.repository_url,
            last_deployment_at: p.last_deployment_at&.iso8601
          }
        }.to_json
      } ]
    when /\Acanine:\/\/projects\/(\d+)\/builds\z/
      project_id = $1.to_i
      projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
      project = projects.find_by(id: project_id)

      return [ { uri: uri, mimeType: "text/plain", text: "Project not found" } ] unless project

      builds = project.builds.order(created_at: :desc).limit(20)
      [ {
        uri: uri,
        mimeType: "application/json",
        text: builds.map { |b|
          {
            id: b.id,
            commit_sha: b.commit_sha,
            commit_message: b.commit_message,
            status: b.status,
            created_at: b.created_at.iso8601
          }
        }.to_json
      } ]
    else
      [ { uri: uri, mimeType: "text/plain", text: "Unknown resource" } ]
    end
  end
end
