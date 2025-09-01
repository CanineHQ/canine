# frozen_string_literal: true

module Projects
  class Update
    extend LightService::Organizer

    def self.call(project, params)
      build_configuration = handle_build_configuration(project, params)

      with(
        project:,
        build_configuration:,
        params:
      ).reduce(
        Projects::UpdateSave
      )
    end

    def self.handle_build_configuration(project, params)
      build_config_params = params[:project][:build_configuration]
      return nil unless build_config_params.present?

      build_config = project.build_configuration || project.build_build_configuration
      build_config.assign_attributes({
          provider_id: project.project_credential_provider.provider_id
        }.merge(BuildConfiguration.permit_params(build_config_params)))
      build_config
    end
  end
end
