# frozen_string_literal: true

module Prompts
  class AddWorkerOrCron < MCP::Prompt
    description "Guide to add a background worker or cron job service to an existing Canine project."

    def self.template(args, server_context:)
      MCP::Prompt::Result.new(
        messages: [
          MCP::Prompt::Message.new(
            role: "user",
            content: MCP::Content::Text.new(<<~TEXT)
              Guide me through adding a background worker or cron job to an existing Canine project.

              ## Step 1 — Find your project
              Call `list_projects` to find your project and note its ID. Show the user the `link_to_view_url` for the project so they can open it in the Canine app.
              Or call `get_project_details` if you already have the project ID, to see existing services.

              ## Step 2 — Create the service
              Call `create_service` with the appropriate type:

              ### Background Worker
              A long-running process (queue consumer, Sidekiq, Celery, etc.):
              - `service_type: "background_service"`
              - `name` — lowercase letters, numbers, hyphens (e.g. "worker", "sidekiq")
              - `command` — (optional) override command, e.g. "bundle exec sidekiq"
              - `replicas` — number of worker processes to run (default: 1)
              - Do NOT set `allow_public_networking` — background services are internal only

              ### Cron Job
              A scheduled task that runs on a schedule and exits:
              - `service_type: "cron_job"`
              - `name` — e.g. "daily-report", "cleanup"
              - `command` — required, the command to run (e.g. "rails send_weekly_digest")
              - `cron_schedule` — a cron expression, e.g.:
                - `"0 * * * *"` — every hour
                - `"0 9 * * 1"` — every Monday at 9am
                - `"*/15 * * * *"` — every 15 minutes

              ## Step 3 — Deploy
              Call `deploy_project` to apply the changes. The new service will be created on the cluster.

              ## Step 4 — Verify
              Call `get_project_details` to confirm the new service appears with the correct status.
              Show the user the project's `link_to_view_url` so they can view the service in the Canine app.
              Call `get_project_logs` if anything looks wrong.
            TEXT
          )
        ]
      )
    end
  end
end
