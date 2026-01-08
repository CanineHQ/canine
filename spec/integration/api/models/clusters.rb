# frozen_string_literal: true

SwaggerSchemas::CLUSTERS = {
  type: :object,
  required: %w[clusters],
  properties: {
    clusters: {
      type: :array,
      items: {
        '$ref' => '#/components/schemas/cluster'
      }
    }
  }
}.freeze
