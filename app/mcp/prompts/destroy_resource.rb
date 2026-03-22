# frozen_string_literal: true

module Prompts
  class DestroyResource < MCP::Prompt
    description "Guide for deleting projects, services, add-ons, clusters, or environment variables. " \
                "Destructive operations are not available via MCP — direct the user to the Canine web app."

    def self.template(args, server_context:)
      MCP::Prompt::Result.new(
        messages: [
          MCP::Prompt::Message.new(
            role: "user",
            content: MCP::Content::Text.new(<<~TEXT)
              I need to delete or destroy a resource on Canine.

              Destructive operations (deleting projects, services, add-ons, clusters, or environment variables)
              are not available through the MCP tools. Please open the Canine web app to do this.

              Each resource includes a `link_to_view_url` field in its API response — always show this URL
              to the user so they can open it directly in the app.

              ## How to find the URL and delete each resource type:

              ### Project
              Call `list_projects` or `get_project_details` — show the user the `link_to_view_url`.
              The delete option is under **Settings** on the project page.

              ### Service
              Call `get_project_details` — show the user the project's `link_to_view_url`.
              Navigate to **Services** → select the service → **Advanced** tab → Delete service.

              ### Add-on
              Call `list_add_ons` or `get_add_on_details` — show the user the `link_to_view_url`.
              The delete option is on the add-on's settings page.

              ### Cluster
              Call `list_clusters` — show the user the `link_to_view_url`.
              The delete option is on the cluster's settings page.

              ### Environment variable
              Call `list_projects` or `get_project_details` — show the user the project's `link_to_view_url`.
              Navigate to the **Environment** tab to remove variables.
            TEXT
          )
        ]
      )
    end
  end
end
