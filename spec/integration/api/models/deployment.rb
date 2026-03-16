# frozen_string_literal: true

SwaggerSchemas::DEPLOYMENT = {
  type: :object,
  required: %w[id version status is_current build_id commit_sha link_to_view_url created_at updated_at],
  properties: {
    id: { type: :integer, example: 1 },
    version: { type: :integer, example: 3 },
    status: { type: :string, example: 'running' },
    is_current: { type: :boolean, example: true },
    build_id: { type: :integer, example: 1 },
    commit_sha: { type: :string, example: 'abc123' },
    commit_message: { type: :string, example: 'Fix bug in authentication', nullable: true },
    link_to_view_url: { type: :string, example: '/projects/example-project/deployments/1' },
    manifests: { type: :object, nullable: true },
    created_at: { type: :string, example: '2024-01-01T00:00:00Z' },
    updated_at: { type: :string, example: '2024-01-01T00:00:00Z' }
  }
}.freeze
