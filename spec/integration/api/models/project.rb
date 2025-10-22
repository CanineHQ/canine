# frozen_string_literal: true

SwaggerSchemas::PROJECT = {
  type: :object,
  required: %w[id name repository_url branch cluster_id subfolder updated_at created_at],
  properties: {
    id: {
      type: :integer,
      example: '1'
    },
    name: {
      type: :string,
      example: 'example-project'
    },
    repository_url: {
      type: :string,
      example: 'https://github.com/example/example-project'
    },
    branch: {
      type: :string,
      example: 'main'
    },
    cluster_id: {
      type: :integer,
      example: '1'
    },
    subfolder: {
      type: :string,
      example: 'example-subfolder'
    },
    updated_at: {
      type: :string,
      example: '2021-01-01T00:00:00Z'
    },
    created_at: {
      type: :string,
      example: '2021-01-01T00:00:00Z'
    },
    url: {
      type: :string,
      example: 'https://example.com/projects/1'
    }
  }
}.freeze
