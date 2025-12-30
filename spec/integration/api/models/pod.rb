# frozen_string_literal: true

SwaggerSchemas::POD = {
  type: :object,
  required: %w[name namespace status created_at],
  properties: {
    name: {
      type: :string,
      example: 'example-project-run-abc123'
    },
    namespace: {
      type: :string,
      example: 'example-project-namespace'
    },
    status: {
      type: :string,
      example: 'Running'
    },
    created_at: {
      type: :string,
      example: '2021-01-01T00:00:00Z'
    },
    labels: {
      type: :object,
      nullable: true,
      example: { app: 'example-project', oneoff: 'true' }
    }
  }
}.freeze
