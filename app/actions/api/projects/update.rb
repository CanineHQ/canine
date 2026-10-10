# frozen_string_literal: true

# Updates a project's settings. Only keys present in params are changed.
module Api
  module Projects
    class Update
      extend LightService::Action
      expects :project, :user, :params
      promises :changes

      PROJECT_ATTRIBUTES = %w[name repository_url branch autodeploy predeploy_command].freeze
      BUILD_CONFIGURATION_ATTRIBUTES = %w[image_repository dockerfile_path context_directory].freeze

      executed do |context|
        params = context.params.to_h.with_indifferent_access.compact
        project_attrs = params.slice(*PROJECT_ATTRIBUTES)
        build_configuration_attrs = params.slice(*BUILD_CONFIGURATION_ATTRIBUTES)

        result = ::Projects::Update.call(
          context.project,
          ActionController::Parameters.new(project: project_attrs.merge(build_configuration: build_configuration_attrs.presence)),
          context.user
        )
        context.fail_and_return!(result.message) if result.failure?

        context.project.reload
        context.changes = project_attrs.merge(build_configuration_attrs)
      end
    end
  end
end
