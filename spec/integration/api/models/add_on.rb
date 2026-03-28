# frozen_string_literal: true

SwaggerSchemas::ADD_ON = {
  type: :object,
  required: %w[id name namespace chart_url version status cluster_id cluster_name link_to_view_url created_at updated_at endpoints],
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
    chart_type: {
      type: :string,
      example: 'helm_chart',
      nullable: true
    },
    repository_url: {
      type: :string,
      example: 'https://charts.bitnami.com/bitnami',
      nullable: true
    },
    version: {
      type: :string,
      example: '17.0.0'
    },
    status: {
      type: :string,
      example: 'installed'
    },
    install_stage: {
      type: :integer,
      example: 0,
      nullable: true
    },
    cluster_id: {
      type: :integer,
      example: 1
    },
    cluster_name: {
      type: :string,
      example: 'production'
    },
    link_to_view_url: {
      type: :string,
      example: '/add_ons/1'
    },
    created_at: {
      type: :string,
      example: '2021-01-01T00:00:00Z'
    },
    updated_at: {
      type: :string,
      example: '2021-01-01T00:00:00Z'
    },
    endpoints: {
      type: :array,
      items: {
        '$ref' => '#/components/schemas/add_on_endpoint'
      }
    }
  }
}.freeze
