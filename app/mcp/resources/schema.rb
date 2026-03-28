# frozen_string_literal: true

module Resources
  class Schema < Base
    def self.uri_pattern
      "canine://schema"
    end

    def self.call(uri:, user:, account_users:)
      schema = {
        resources: [
          { uri: "canine://accounts", description: "List all accounts accessible to the current user. Account IDs are required for all other resource URIs." },
          { uri: "canine://providers", description: "List all Git and container registry providers. Provider IDs are required when creating projects." }
        ],
        resource_templates: [
          { uri_template: "canine://accounts/{account_id}/clusters", description: "List all clusters for an account." },
          { uri_template: "canine://accounts/{account_id}/projects", description: "List all projects for an account (lightweight — no services or builds)." },
          { uri_template: "canine://accounts/{account_id}/projects/{project_id}", description: "Full project details including services, domains, volumes, and recent builds." },
          { uri_template: "canine://accounts/{account_id}/projects/{project_id}/builds", description: "Build history for a project. Each build includes its deployment and status." },
          { uri_template: "canine://accounts/{account_id}/projects/{project_id}/environment_variables", description: "Environment variable names and storage types for a project. Values are not included — use the get_environment_variable_value tool to read a specific value." },
          { uri_template: "canine://accounts/{account_id}/add_ons", description: "List all add-ons for an account (databases, caches, third-party Helm charts)." },
          { uri_template: "canine://accounts/{account_id}/add_ons/{add_on_id}", description: "Full add-on details including endpoints, internal connection URLs, and pod status." }
        ]
      }

      json(uri, schema)
    end
  end
end
