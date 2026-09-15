# frozen_string_literal: true

module Projects
  class UpdateSave
    extend LightService::Action

    expects :project, :params, :build_configuration
    promises :project

    executed do |context|
      was_internal = context.project.internal?

      ActiveRecord::Base.transaction do
        # Update project with permitted params
        context.project.assign_attributes(Projects::Create.create_params(context.params))
        context.project.repository_url = context.project.repository_url.strip.downcase if context.project.repository_url_changed?
        context.project.save!

        # Save project credential provider if changed
        context.project.project_credential_provider.save! if context.project.project_credential_provider.changed?

        # Save build configuration if present
        context.build_configuration&.save!
      end

      # Manage OAuth application for internal auth proxy
      if context.project.internal? && !was_internal
        unless context.project.oauth_application.present?
          context.project.create_oauth_application!(
            name: "Auth Proxy: #{context.project.name}",
            redirect_uri: "#{ENV.fetch('APP_HOST')}/oauth2/callback",
            scopes: "openid profile",
            confidential: true
          )
        end
      elsif was_internal && !context.project.internal?
        context.project.oauth_application&.destroy
      end
    rescue => e
      context.fail_and_return!(e.message)
    end
  end
end
