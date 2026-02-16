# frozen_string_literal: true

SwaggerSchemas::ADD_ON = {
  type: :object,
  required: %w[id name namespace chart_url version status cluster_id cluster_name created_at updated_at],
  properties: {
    id: {
      type: :integer,
      example: 1
    },
    name: {
      type: :string,
      example: 'redis'
    },
    namespace: {
      type: :string,
      example: 'redis'
    },
    chart_url: {
      type: :string,
      example: 'https://charts.bitnami.com/bitnami/redis'
    },
    version: {
      type: :string,
      example: '17.0.0'
    },
    status: {
      type: :string,
      example: 'installed'
    },
    cluster_id: {
      type: :integer,
      example: 1
    },
    cluster_name: {
      type: :string,
      example: 'production'
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
