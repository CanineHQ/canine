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
      prompts: mcp_prompts,
      resources: mcp_resources,
      resource_templates: mcp_resource_templates,
      server_context: { token: doorkeeper_token, user_id: doorkeeper_token.resource_owner_id }
    )

    server.resources_read_handler do |params, server_context:|
      Resources::Router.call(params[:uri], server_context)
    end

    server
  end

  def mcp_tools
    [
      # Clusters
      Tools::CreateCluster,
      Tools::GetClusterKubeconfig,

      # Projects
      Tools::CreateProject,
      Tools::CreateService,
      Tools::DeployProject,
      Tools::RestartProject,

      # Project Logs & Monitoring
      Tools::GetProjectLogs,
      # Environment Variables
      Tools::GetEnvironmentVariableValue,
      Tools::UpdateEnvironmentVariable,

      # Add-ons
      Tools::SearchAddOns,
      Tools::CreateAddOn,
      Tools::GetAddOnLogs
    ]
  end

  def mcp_prompts
    [
      Prompts::DeployNewProject,
      Prompts::AddWorkerOrCron,
      Prompts::TroubleshootDeployment,
      Prompts::InstallAddOn,
      Prompts::DestroyResource
    ]
  end

  def mcp_resources
    [
      MCP::Resource.new(
        uri: "canine://accounts",
        name: "accounts",
        description: "List all accounts accessible to the current user, including their clusters with project and add-on counts",
        mime_type: "application/json"
      ),
      MCP::Resource.new(
        uri: "canine://providers",
        name: "providers",
        description: "List all Git and container registry providers configured for the current user. Provider IDs are required when creating projects.",
        mime_type: "application/json"
      ),
      MCP::Resource.new(
        uri: "canine://clusters",
        name: "clusters",
        description: "List all clusters accessible to the current user",
        mime_type: "application/json"
      ),
      MCP::Resource.new(
        uri: "canine://projects",
        name: "projects",
        description: "List all projects accessible to the current user",
        mime_type: "application/json"
      ),
      MCP::Resource.new(
        uri: "canine://add_ons",
        name: "add_ons",
        description: "List all add-ons accessible to the current user. Add-ons are databases, caches, and third-party Helm charts installed on a cluster — e.g. PostgreSQL, Redis, Metabase, Airbyte, Dagster.",
        mime_type: "application/json"
      )
    ]
  end

  def mcp_resource_templates
    [
      MCP::ResourceTemplate.new(
        uri_template: "canine://projects/{project_id}/environment_variables",
        name: "project-environment-variables",
        description: "List all environment variable names and storage types for a project (values are not included)",
        mime_type: "application/json"
      ),
      MCP::ResourceTemplate.new(
        uri_template: "canine://projects/{project_id}",
        name: "project",
        description: "Full details for a project including services, domains, volumes, and recent builds",
        mime_type: "application/json"
      ),
      MCP::ResourceTemplate.new(
        uri_template: "canine://projects/{project_id}/builds",
        name: "project-builds",
        description: "List builds for a specific project",
        mime_type: "application/json"
      ),
      MCP::ResourceTemplate.new(
        uri_template: "canine://add_ons/{add_on_id}",
        name: "add_on",
        description: "Full details for an add-on (database, cache, or third-party Helm chart such as Metabase, Airbyte, or Dagster) including endpoints, connection URLs, and status",
        mime_type: "application/json"
      )
    ]
  end
end
