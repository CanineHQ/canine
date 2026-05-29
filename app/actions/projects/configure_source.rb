# frozen_string_literal: true

module Projects
  class ConfigureSource
    extend LightService::Action

    expects :project, :params, :user
    promises :provider, :project_credential_provider

    executed do |context|
      project = context.project
      provider = find_provider(context.user, context.params)

      if context.params[:project][:public_image_url].present?
        configure_from_public_image_url(project, context.params)
        context.provider = nil
        context.project_credential_provider = nil
      elsif provider
        configure_from_provider(project, provider)
        context.provider = provider
        context.project_credential_provider = ProjectCredentialProvider.new(project:, provider:)
      else
        context.fail_and_return!("A provider or public image URL is required")
      end
    end

    def self.find_provider(user, params)
      provider_params = params[:project][:project_credential_provider]
      return nil unless provider_params.present? && provider_params[:provider_id].present?

      user.providers.find(provider_params[:provider_id])
    rescue ActiveRecord::RecordNotFound
      raise "Provider #{provider_params[:provider_id]} not found"
    end

    def self.configure_from_provider(project, provider)
      project.provider_type = provider.provider
      project.repository_base_url = provider.source_base_url
    end

    def self.configure_from_public_image_url(project, params)
      url = params[:project][:public_image_url]
      return unless url.present?

      project.provider_type = Provider::CUSTOM_REGISTRY_PROVIDER

      # Extract tag from the end (e.g., "docker.io/library/nginx:latest")
      # Use rindex to find the last colon, avoiding port colons (e.g., localhost:5000/repo)
      last_colon = url.rindex(":")
      if last_colon && !url[last_colon..].include?("/")
        image = url[0...last_colon]
        project.branch = url[(last_colon + 1)..]
      else
        image = url
        project.branch = "latest"
      end

      # Split "docker.io/library/nginx" into base_url and repository path
      # The first segment with a dot or colon is the registry host
      parts = image.split("/")
      if parts.first&.match?(/[.:]/)
        project.repository_base_url = parts.first
        project.repository_url = parts[1..].join("/")
      else
        # No registry host (e.g., "library/nginx" or "nginx") — assume Docker Hub
        project.repository_base_url = "docker.io"
        project.repository_url = image
      end
    end
  end
end
