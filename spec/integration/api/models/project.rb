# frozen_string_literal: true

SwaggerSchemas::PROJECT = {
  type: :object,
  required: %w[id name namespace repository_url branch status cluster_id cluster_name container_registry_url updated_at created_at],
  properties: {
    id: {
      type: :integer,
      example: 1
    },
    name: {
      type: :string,
      example: 'example-project'
    },
    namespace: {
      type: :string,
      example: 'example-project'
    },
    repository_url: {
      type: :string,
      example: 'https://github.com/example/example-project'
    },
    branch: {
      type: :string,
      example: 'main'
    },
    status: {
      type: :string,
      example: 'deployed'
    },
    cluster_id: {
      type: :integer,
      example: 1
    },
    cluster_name: {
      type: :string,
      example: 'production'
    },
    container_registry_url: {
      type: :string,
      example: 'ghcr.io/example/example-project:main'
    },
    updated_at: {
      type: :string,
      example: '2021-01-01T00:00:00Z'
    },
    created_at: {
      type: :string,
      example: '2021-01-01T00:00:00Z'
    }
  }
}.freeze
