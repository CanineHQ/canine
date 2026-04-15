FactoryBot.define do
  factory :development_environment_configuration do
    project
    dockerfile_path { "./Dockerfile.dev" }
    workspace_mount_path { "/app" }
    enabled { true }
  end
end
