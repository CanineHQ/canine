# frozen_string_literal: true

module Projects
  class Update
    extend LightService::Organizer

    def self.call(project, params)
      build_configuration = handle_build_configuration(project, params)
      handle_project_credential_provider(project, params)

      with(
        project:,
        build_configuration:,
        params:
      ).reduce(
        Projects::UpdateSave,
        Projects::UpdateBuildPacks
      )
    end

    def self.handle_project_credential_provider(project, params)
      provider_params = params[:project][:project_credential_provider_attributes]
      return unless provider_params.present? && provider_params[:provider_id].present?

      provider = user.providers.find(provider_params[:provider_id])
      project.project_credential_provider.provider = provider
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
