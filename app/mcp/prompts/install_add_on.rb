# frozen_string_literal: true

module Prompts
  class InstallAddOn < MCP::Prompt
    description "Guide to install any Helm chart as a Canine add-on — databases, caches, queues, or anything available on Artifact Hub or any Helm repository."

    def self.template(args, server_context:)
      MCP::Prompt::Result.new(
        messages: [
          MCP::Prompt::Message.new(
            role: "user",
            content: MCP::Content::Text.new(<<~TEXT)
              Guide me through installing a Helm chart add-on on Canine.

              Canine add-ons let you deploy any Helm chart — databases, caches, message queues, monitoring tools,
              or anything available on Artifact Hub (artifacthub.io) or any public/private Helm repository.

              ## Step 1 — Find your cluster
              Call `list_accounts` to get the cluster_id you want to install on.

              ## Step 2 — Find the chart
              Call `search_add_ons` with a search term (e.g. "postgresql", "redis", "rabbitmq", "kafka", "mongodb", "mysql", "minio").

              The response includes:
              - `curated` — Canine-curated charts with known-good defaults
              - `artifact_hub` — results from Artifact Hub

              Each result contains the `chart_url` (e.g. "bitnami/redis"), `version`, and `repository_url` needed for installation.

              If the chart you want isn't in the search results, you can use any Helm chart directly by providing:
              - `chart_url` — "repo-name/chart-name"
              - `repository_url` — the Helm repo URL (e.g. "https://charts.bitnami.com/bitnami")
              - `version` — the chart version to install

              ## Step 3 — Install the add-on
              Call `create_add_on` with:
              - `name` — a unique name for this instance (e.g. "main-postgres", "cache-redis")
              - `chart_url` — from search results
              - `version` — from search results
              - `repository_url` — from search results
              - `cluster_id` — from Step 1
              - `values_yaml` — (optional) custom Helm values as a YAML string to override chart defaults

              ## Step 4 — Wait for it to be ready
              Call `get_add_on_details` with the add_on_id.
              Check the `processes` array — wait until pod status shows "Running".
              Use `include_values: true` to see the full Helm values (useful for finding connection strings, passwords, etc.).

              ## Step 5 — Wire it to your project
              Most add-ons expose a Kubernetes service inside the cluster. The internal hostname follows the pattern:
              `<addon-name>.<addon-name>.svc.cluster.local`

              For example, for a Bitnami Postgres add-on named "main-postgres":
              - Host: `main-postgres-postgresql.main-postgres.svc.cluster.local`
              - Default port: `5432`

              Call `update_environment_variable` on your project with `storage_type: "secret"` to set the connection string, e.g.:
              `DATABASE_URL=postgresql://postgres:<password>@main-postgres-postgresql.main-postgres.svc.cluster.local:5432/mydb`

              Then call `deploy_project` to apply the changes.

              ## Useful add-ons on Artifact Hub
              - **Databases**: bitnami/postgresql, bitnami/mysql, bitnami/mongodb, bitnami/mariadb
              - **Caches**: bitnami/redis, bitnami/memcached
              - **Queues**: bitnami/rabbitmq, bitnami/kafka
              - **Storage**: bitnami/minio
              - **Search**: bitnami/elasticsearch, bitnami/opensearch
              - **Monitoring**: prometheus-community/kube-prometheus-stack, grafana/grafana
              - **Anything else**: search artifacthub.io for the chart name and repo
            TEXT
          )
        ]
      )
    end
  end
end
