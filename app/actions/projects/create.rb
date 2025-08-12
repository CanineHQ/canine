# frozen_string_literal: true

module Projects
  class Create
    extend LightService::Organizer
    def self.create_params(params)
      params.require(:project).permit(
        :name,
        :repository_url,
        :branch,
        :cluster_id,
        :docker_build_context_directory,
        :docker_command,
        :dockerfile_path,
        :container_registry_url,
        :predeploy_command,
        :project_fork_status,
        :project_fork_cluster_id,
      )
    end

    def self.call(
      params,
      user
    )
      project = Project.new(create_params(params))
      provider = find_provider(user, params)
      project_credential_provider = create_project_credential_provider(project, provider)

      steps = create_steps(provider)
      with(
        project:,
        project_credential_provider:,
        params:,
        user:
      ).reduce(*steps)
    end

    def self.create_project_credential_provider(project, provider)
      ProjectCredentialProvider.new(
        project:,
        provider:,
      )
    end

    def self.create_steps(provider)
      steps = []
      if provider.git?
        steps << Projects::ValidateGitRepository
      end

      steps << Projects::Save

      # Only register webhook in non-local mode
      if !Rails.application.config.local_mode && provider.git?
        steps << Projects::RegisterGitWebhook
      end
      steps
    end

    def self.find_provider(user, params)
      provider_id = params[:project][:project_credential_provider][:provider_id]
      user.providers.find(provider_id)
    rescue ActiveRecord::RecordNotFound
      raise "Provider #{provider_id} not found"
    end
  end
end
