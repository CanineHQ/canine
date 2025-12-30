# frozen_string_literal: true

SwaggerSchemas::CLUSTERS = {
  type: :array,
  items: {
    '$ref' => '#/components/schemas/cluster'
  }
}.freeze
