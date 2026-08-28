# frozen_string_literal: true

SwaggerSchemas::WORKBENCH = {
  type: :object,
  required: %w[pod_name namespace container workspace_mount_path cluster_name],
  properties: {
    pod_name: {
      type: :string,
      example: 'workbench-pod-abc123'
    },
    namespace: {
      type: :string,
      example: 'my-project'
    },
    container: {
      type: :string,
      example: 'my-project'
    },
    workspace_mount_path: {
      type: :string,
      example: '/workspace'
    },
    cluster_name: {
      type: :string,
      example: 'production'
    }
  }
}.freeze
