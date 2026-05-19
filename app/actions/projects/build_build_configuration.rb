# frozen_string_literal: true

module Projects
  class BuildBuildConfiguration
    extend LightService::Action

    expects :project, :params
    promises :build_configuration

    executed do |context|
      project = context.project
      unless project.git?
        context.build_configuration = nil
        next context
      end

      build_config_params = context.params[:project][:build_configuration] || ActionController::Parameters.new
      default_params = default_build_configuration(project)
      merged_params = default_params.merge(BuildConfiguration.permit_params(build_config_params).compact_blank)
      context.build_configuration = project.build_build_configuration(merged_params)
    end

    def self.default_build_configuration(project)
      git_provider = project.project_credential_provider.provider
      {
        provider: git_provider.has_native_container_registry? ? git_provider : nil,
        driver: BuildConfiguration::DEFAULT_BUILDER,
        build_type: :dockerfile,
        image_repository: project.repository_url,
        context_directory: ".",
        dockerfile_path: "./Dockerfile"
      }.compact
    end
  end
end
