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
      :autodeploy,
      :predeploy_command,
      :project_fork_status,
      :project_fork_cluster_id,
      :public_image_url
    )
  end

  def self.call(params, user)
    project = Project.new(create_params(params))

    with(
      project:,
      params:,
      user:
    ).reduce(*steps)
  end

  def self.steps
    [
      Projects::ConfigureSource,
      Projects::BuildBuildConfiguration,
      Projects::ValidateGitRepository,
      Projects::Create::ToNamespaced,
      Projects::BuildDeploymentConfiguration,
      Namespaced::SetUpNamespace,
      Namespaced::ValidateNamespace,
      Projects::InitializeBuildPacks,
      Projects::Save,
      Projects::RegisterGitWebhook
    ]
  end
end
