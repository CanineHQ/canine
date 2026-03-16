# frozen_string_literal: true

module Prompts
  class DeployNewProject < MCP::Prompt
    description "Step-by-step guide to create and deploy a new project on Canine, from zero to a live URL. " \
                "Covers project creation, services, environment variables, optional database/add-on setup, and first deploy."

    def self.template(args, server_context:)
      MCP::Prompt::Result.new(
        messages: [
          MCP::Prompt::Message.new(
            role: "user",
            content: MCP::Content::Text.new(<<~TEXT)
              Guide me through deploying a new project on Canine from scratch.

              Follow these steps in order:

              ## Step 1 — Gather required IDs
              - Call `list_accounts` to get your account ID and available cluster IDs.
              - Call `list_providers` to get the Git provider ID for your repository (GitHub, GitLab, etc.).

              ## Step 2 — (Optional) Install a database or other add-on
              If the project needs a database or any backing service (Postgres, Redis, MySQL, etc.):
              - Call `search_add_ons` with a query like "postgresql" or "redis" to find the chart.
              - Call `create_add_on` with the chart_url, version, repository_url, and cluster_id.
              - Call `get_add_on_details` to check its status until it shows as running. Show the user the `link_to_view_url` so they can open it in the Canine app.
              - Note the connection string format from the add-on's Helm values — you'll set this as an environment variable after creating the project.

              ## Step 3 — Create the project
              Call `create_project` with:
              - `name` — lowercase letters, numbers, hyphens only
              - `repository_url` — in "owner/repo" format (e.g. "myorg/my-app")
              - `cluster_id` — from Step 1
              - `provider_id` — from Step 1
              - `branch` — defaults to "main"
              - `predeploy_command` — (optional) e.g. "rails db:migrate" or "npm run migrate"
              - `dockerfile_path` — (optional) defaults to "./Dockerfile"

              Once created, show the user the project's `link_to_view_url` so they can open it in the Canine app.

              ## Step 4 — Create a service
              Every project needs at least one service to be deployable. Call `create_service` with:
              - `project_id` — from the project created above
              - `name` — lowercase letters, numbers, hyphens only
              - `service_type` — use "web_service" for HTTP apps, "background_service" for workers
              - `allow_public_networking: true` — set this if the service should be accessible from the internet; Canine will auto-create a domain and DNS entry
              - `container_port` — the port your app listens on (default: 3000)
              - `healthcheck_url` — (optional) e.g. "/health" — just needs to return HTTP 200

              ## Step 5 — Set environment variables
              Call `update_environment_variable` for each required env var:
              - Use `storage_type: "secret"` for sensitive values (DATABASE_URL, API keys, passwords)
              - Use `storage_type: "config"` for non-sensitive values (RAILS_ENV, NODE_ENV, etc.)
              - Redeploy is required after changes — don't deploy until all variables are set.

              ## Step 6 — Deploy
              Call `deploy_project` with the project_id to trigger the first build and deployment.

              ## Step 7 — Verify
              Call `get_project_details` to check the deployment status and find the auto-assigned public domain under each service's `domains` array.

              If the deployment succeeds and a service has a domain, display it to the user like this:
              🎉 Your app is live at https://<domain_name>

              Also show the project's `link_to_view_url` so the user can open it in the Canine app.

              If the deployment fails, call `get_project_logs` to see build and runtime logs.
            TEXT
          )
        ]
      )
    end
  end
end
