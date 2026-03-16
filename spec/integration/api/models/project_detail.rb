# frozen_string_literal: true

SwaggerSchemas::PROJECT_DETAIL = {
  allOf: [
    { '$ref' => '#/components/schemas/project' },
    {
      type: :object,
      properties: {
        autodeploy: { type: :boolean, example: true },
        dockerfile_path: { type: :string, example: 'Dockerfile', nullable: true },
        docker_build_context_directory: { type: :string, example: '.', nullable: true },
        predeploy_command: { type: :string, example: 'bundle exec rails db:migrate', nullable: true },
        postdeploy_command: { type: :string, example: nil, nullable: true },
        services: {
          type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              name: { type: :string, example: 'web' },
              service_type: { type: :string, example: 'web' },
              status: { type: :string, example: 'running' },
              replicas: { type: :integer, example: 1 },
              container_port: { type: :integer, example: 3000, nullable: true },
              command: { type: :string, example: nil, nullable: true },
              healthcheck_url: { type: :string, example: '/health', nullable: true },
              allow_public_networking: { type: :boolean, example: true },
              domains: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, example: 1 },
                    domain_name: { type: :string, example: 'example.com' },
                    status: { type: :string, example: 'active' }
                  }
                }
              }
            }
          }
        },
        volumes: {
          type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              name: { type: :string, example: 'data' },
              mount_path: { type: :string, example: '/app/storage' },
              size: { type: :string, example: '10Gi' },
              access_mode: { type: :string, example: 'ReadWriteOnce' },
              status: { type: :string, example: 'bound' }
            }
          }
        },
        builds: {
          type: :array,
          items: { '$ref' => '#/components/schemas/build' }
        }
      }
    }
  ]
}.freeze
