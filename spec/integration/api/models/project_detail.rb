# frozen_string_literal: true

SwaggerSchemas::PROJECT_DETAIL = {
  type: :object,
  required: %w[id name namespace repository_url branch status cluster_id cluster_name container_registry_url link_to_view_url updated_at created_at autodeploy services volumes builds],
  properties: {
    id: { type: :integer, example: 1 },
    name: { type: :string, example: 'example-project' },
    namespace: { type: :string, example: 'example-project' },
    repository_url: { type: :string, example: 'https://github.com/example/example-project' },
    branch: { type: :string, example: 'main' },
    status: { type: :string, example: 'deployed' },
    cluster_id: { type: :integer, example: 1 },
    cluster_name: { type: :string, example: 'production' },
    container_registry_url: { type: :string, example: 'ghcr.io/example/example-project:main' },
    link_to_view_url: { type: :string, example: '/projects/example-project' },
    last_deployment_at: { type: :string, example: '2024-01-01T00:00:00Z', nullable: true },
    current_commit_message: { type: :string, example: 'Fix bug in authentication', nullable: true },
    created_at: { type: :string, example: '2024-01-01T00:00:00Z' },
    updated_at: { type: :string, example: '2024-01-01T00:00:00Z' },
    autodeploy: { type: :boolean, example: true },
    dockerfile_path: { type: :string, example: 'Dockerfile', nullable: true },
    docker_build_context_directory: { type: :string, example: '.', nullable: true },
    predeploy_command: { type: :string, example: 'bundle exec rails db:migrate', nullable: true },
    postdeploy_command: { type: :string, example: nil, nullable: true },
    services: {
      type: :array,
      items: {
        type: :object,
        properties: {
          id: { type: :integer, example: 1 },
          name: { type: :string, example: 'web' },
          service_type: { type: :string, example: 'web' },
          status: { type: :string, example: 'running' },
          replicas: { type: :integer, example: 1 },
          container_port: { type: :integer, example: 3000, nullable: true },
          command: { type: :string, example: nil, nullable: true },
          healthcheck_url: { type: :string, example: '/health', nullable: true },
          allow_public_networking: { type: :boolean, example: true },
          domains: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :integer, example: 1 },
                domain_name: { type: :string, example: 'example.com' },
                status: { type: :string, example: 'active' }
              }
            }
          }
        }
      }
    },
    volumes: {
      type: :array,
      items: {
        type: :object,
        properties: {
          id: { type: :integer, example: 1 },
          name: { type: :string, example: 'data' },
          mount_path: { type: :string, example: '/app/storage' },
          size: { type: :string, example: '10Gi' },
          access_mode: { type: :string, example: 'ReadWriteOnce' },
          status: { type: :string, example: 'bound' }
        }
      }
    },
    builds: {
      type: :array,
      items: {
        type: :object,
        properties: {
          id: { type: :integer, example: 1 },
          status: { type: :string, example: 'completed' },
          commit_sha: { type: :string, example: 'abc123' },
          commit_message: { type: :string, example: 'Fix bug in authentication', nullable: true },
          created_at: { type: :string, example: '2024-01-01T00:00:00Z' },
          log_tail: { type: :string, example: "Step 1/10 : FROM ruby:3.2\n..." }
        }
      }
    }
  }
}.freeze
