module Providers
  # Pushes a provider's current token into the image pull secret of every deployed project that pulls with it,
  # so running pods (and pods rescheduled later) can pull without a redeploy.
  class SyncRegistrySecretsJob < ApplicationJob
    queue_as :default

    def perform(provider, user)
      self.class.projects_for(provider).each do |project|
        kubectl = K8::Kubectl.new(K8::Connection.new(project, user, allow_anonymous: true))
        result = Projects::ApplyRegistrySecret.execute(project:, kubectl:)
        Rails.logger.error("Registry secret sync failed for project #{project.id}: #{result.message}") if result.failure?
      rescue StandardError => e
        Rails.logger.error("Registry secret sync failed for project #{project.id}: #{e.message}")
      end
    end

    def self.projects_for(provider)
      project_ids = ProjectCredentialProvider.where(provider:).pluck(:project_id) +
        BuildConfiguration.where(provider:).pluck(:project_id)

      Project.deployed.where(id: project_ids.uniq)
        .select { |project| !project.public_image? && project.build_provider == provider }
    end
  end
end
