# frozen_string_literal: true

SwaggerSchemas::BUILD = {
  type: :object,
  required: %w[id status commit_sha link_to_view_url logs created_at updated_at],
  properties: {
    id: { type: :integer, example: 1 },
    status: { type: :string, example: 'completed' },
    commit_sha: { type: :string, example: 'abc123' },
    commit_message: { type: :string, example: 'Fix bug in authentication', nullable: true },
    git_sha: { type: :string, example: 'abc123', nullable: true },
    repository_url: { type: :string, example: 'https://github.com/example/example-project', nullable: true },
    project_id: { type: :integer, example: 1 },
    project_name: { type: :string, example: 'example-project' },
    link_to_view_url: { type: :string, example: '/projects/example-project/deployments/1' },
    logs: { type: :string, example: "Step 1/10 : FROM ruby:3.2\n..." },
    created_at: { type: :string, example: '2024-01-01T00:00:00Z' },
    updated_at: { type: :string, example: '2024-01-01T00:00:00Z' },
    deployment: { '$ref' => '#/components/schemas/deployment', nullable: true }
  }
}.freeze
