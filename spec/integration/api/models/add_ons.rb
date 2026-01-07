# frozen_string_literal: true

SwaggerSchemas::ADD_ONS = {
  type: :object,
  required: %w[add_ons],
  properties: {
    add_ons: {
      type: :array,
      items: {
        '$ref' => '#/components/schemas/add_on'
      }
    }
  }
}.freeze
