# frozen_string_literal: true

SwaggerSchemas::ADD_ON_ENDPOINT = {
  type: :object,
  required: %w[name internal_urls external_urls],
  properties: {
    name: {
      type: :string,
      example: 'redis-master'
    },
    internal_urls: {
      type: :array,
      items: { type: :string },
      example: [ 'redis-master.redis.svc.cluster.local:6379' ]
    },
    external_urls: {
      type: :array,
      items: { type: :string },
      example: [ 'redis.example.com' ]
    }
  }
}.freeze
