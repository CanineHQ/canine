# frozen_string_literal: true

SwaggerSchemas::PROJECTS = {
  type: :object,
  required: %w[projects],
  properties: {
    projects: {
      type: :array,
      items: {
        '$ref' => '#/components/schemas/project'
      }
    }
  }
}.freeze
