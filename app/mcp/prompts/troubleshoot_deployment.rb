# frozen_string_literal: true

module Prompts
  class TroubleshootDeployment < MCP::Prompt
    description "Guide to diagnose and fix a failing build or deployment on Canine."

    def self.template(args, server_context:)
      MCP::Prompt::Result.new(
        messages: [
          MCP::Prompt::Message.new(
            role: "user",
            content: MCP::Content::Text.new(<<~TEXT)
              Help me troubleshoot a failing deployment on Canine.

              ## Step 1 — Check project and service status
              Call `get_project_details` with the project_id.
              Show the user the project's `link_to_view_url` so they can open it directly in the Canine app.
              Look at:
              - Top-level `status` — is the project healthy, pending, or unhealthy?
              - Each service's `status` — which specific service is failing?
              - The `builds` array — find the most recent build and check its `status` and `deployment` fields. Show the build's `link_to_view_url` so the user can view the full build log in the app.

              ## Step 2 — Read the logs
              Call `get_project_logs` with the project_id.
              - **Build failures** show up as errors during the Docker build phase — look for lines like "ERROR", "failed to", "exit code".
              - **Runtime failures** (crash loops, unhealthy) appear as application errors after the container starts — look for unhandled exceptions, missing env vars, or connection errors.

              ## Common causes and fixes:

              ### Build failing
              - Missing or incorrect `dockerfile_path` — check that the Dockerfile exists at the specified path
              - Docker build errors — fix the Dockerfile or application code and redeploy
              - Git credentials issue — ensure the provider_id has access to the repository

              ### App crashing at startup (runtime failure)
              - Missing environment variable — call `get_environment_variable_keys` to list what's set, then `update_environment_variable` to add the missing one
              - Wrong `container_port` — ensure the service's container_port matches what your app actually listens on
              - Database not reachable — check that the add-on is running via `get_add_on_details` (show the user its `link_to_view_url`) and that DATABASE_URL is set correctly

              ### Predeploy command failing (e.g. db:migrate)
              - Database add-on may not be installed yet — use the `install_add_on` prompt
              - DATABASE_URL not set — call `update_environment_variable` with `storage_type: "secret"`

              ### Service stuck in "pending"
              - Cluster may be out of resources — check with `list_clusters`
              - Healthcheck URL returning non-200 — update the service's `healthcheck_url` or fix the endpoint

              ## Step 3 — Fix and redeploy
              After making changes (env vars, service config), call `deploy_project` to trigger a new build and deployment.
              Once resolved, show the user the project's `link_to_view_url` and any live service domain URLs.
            TEXT
          )
        ]
      )
    end
  end
end
