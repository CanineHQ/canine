# frozen_string_literal: true

class Projects::Create
  class ToNamespaced
    extend LightService::Action
    expects :project
    promises :namespaced
    executed do |context|
      context.namespaced = context.project
    end
  end

  extend LightService::Organizer
  def self.create_params(params)
    params.require(:project).permit(
      :name,
      :namespace,
      :managed_namespace,
      :repository_url,
      :branch,
      :cluster_id,
      :container_registry_url,
      :predeploy_command,
      :project_fork_status,
      :project_fork_cluster_id
    )
  end

  def self.call(
    params,
    user
  )
    project = Project.new(create_params(params))
    provider = find_provider(user, params)
    project_credential_provider = build_project_credential_provider(project, provider)
    build_configuration = build_build_configuration(project, params)

    steps = create_steps(provider)
    with(
      project:,
      project_credential_provider:,
      build_configuration:,
      params:,
      user:
    ).reduce(*steps)
  end

  def self.build_project_credential_provider(project, provider)
    ProjectCredentialProvider.new(
      project:,
      provider:,
    )
  end

  def self.build_build_configuration(project, params)
    return unless project.git?
    build_config_params = params[:project][:build_configuration] || ActionController::Parameters.new
    default_params = build_default_build_configuration(project)
    merged_params = default_params.merge(BuildConfiguration.permit_params(build_config_params).compact_blank)
    build_configuration = project.build_build_configuration(merged_params)
    build_configuration
  end

  def self.build_default_build_configuration(project)
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

  def self.create_steps(provider)
    steps = []
    if provider.git?
      steps << Projects::ValidateGitRepository
    end

    steps << Projects::Create::ToNamespaced
    steps << Projects::BuildDeploymentConfiguration
    steps << Namespaced::SetUpNamespace
    steps << Namespaced::ValidateNamespace
    steps << Projects::InitializeBuildPacks
    steps << Projects::Save

    # Only register webhook in cloud mode
    if Rails.application.config.cloud_mode && provider.git?
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
