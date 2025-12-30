# frozen_string_literal: true

SwaggerSchemas::CLUSTER = {
  type: :object,
  required: %w[id name cluster_type status created_at updated_at],
  properties: {
    id: {
      type: :integer,
      example: 1
    },
    name: {
      type: :string,
      example: 'production-cluster'
    },
    cluster_type: {
      type: :string,
      example: 'k8s'
    },
    status: {
      type: :string,
      example: 'ready'
    },
    created_at: {
      type: :string,
      example: '2021-01-01T00:00:00Z'
    },
    updated_at: {
      type: :string,
      example: '2021-01-01T00:00:00Z'
    }
  }
}.freeze
