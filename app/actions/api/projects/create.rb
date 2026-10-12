# frozen_string_literal: true

# Creates a project on a cluster, either from a git repository or a public container image.
# params: name, repository_url + provider_id (git), or public_image_url (image),
#         branch, dockerfile_path, context_directory, predeploy_command
module Api
  module Projects
    class Create
      extend LightService::Action
      expects :user, :cluster, :params
      promises :project

      executed do |context|
        params = context.params.to_h.with_indifferent_access

        project_params = {
          name: params[:name],
          cluster_id: context.cluster.id,
          managed_namespace: true,
          predeploy_command: params[:predeploy_command]
        }

        if params[:public_image_url].present?
          project_params[:public_image_url] = params[:public_image_url]
        else
          provider = context.user.providers.find_by(id: params[:provider_id])
          unless provider
            context.fail_and_return!("Provider not found. Pass the ID of one of your git providers, or a public_image_url to deploy a public image.")
          end

          project_params.merge!(
            repository_url: params[:repository_url],
            branch: params[:branch].presence || "main",
            project_credential_provider: { provider_id: provider.id },
            build_configuration: {
              dockerfile_path: params[:dockerfile_path].presence || "./Dockerfile",
              context_directory: params[:context_directory].presence || "."
            }
          )
        end

        result = ::Projects::Create.call(ActionController::Parameters.new(project: project_params), context.user)

        if result.failure?
          context.fail_and_return!(result.project&.errors&.full_messages&.to_sentence.presence || result.message)
        end

        context.project = result.project
      end
    end
  end
end
