# frozen_string_literal: true

SwaggerSchemas::PODS = {
  type: :object,
  required: %w[pods],
  properties: {
    pods: {
      type: :array,
      items: {
        '$ref' => '#/components/schemas/pod'
      }
    }
  }
}.freeze
