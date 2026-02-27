class CanineConfig::RestoreProject
  extend LightService::Action

  expects :definition, :target_cluster
  promises :project

  executed do |context|
    definition = context.definition
    target_cluster = context.target_cluster
    project_attrs = definition["project"]

    ActiveRecord::Base.transaction do
      project = Project.new(
        cluster: target_cluster,
        status: :creating,
        repository_url: project_attrs["repository_url"],
        branch: project_attrs["branch"],
        dockerfile_path: project_attrs["dockerfile_path"],
        docker_build_context_directory: project_attrs["docker_build_context_directory"],
        container_registry_url: project_attrs["container_registry_url"],
        managed_namespace: project_attrs["managed_namespace"],
        autodeploy: project_attrs["autodeploy"]
      )

      # Apply lifecycle scripts
      if definition["scripts"].present?
        project.predeploy_command = definition.dig("scripts", "predeploy")
        project.postdeploy_command = definition.dig("scripts", "postdeploy")
        project.predestroy_command = definition.dig("scripts", "predestroy")
        project.postdestroy_command = definition.dig("scripts", "postdestroy")
      end

      # Generate unique name and slug
      base_name = context[:custom_name] || project_attrs["name"] || project_attrs["repository_url"]&.split("/")&.last
      project.name = base_name
      while Project.joins(:cluster).where(clusters: { account_id: target_cluster.account_id }, name: project.name).exists?
        project.name = "#{base_name}-#{SecureRandom.hex(4)}"
      end
      project.namespace = context[:custom_namespace] || project.name
      project.managed_namespace = context[:managed_namespace] if context[:custom_namespace].present?
      project.generate_slug

      # Credential provider
      project.build_project_credential_provider(
        provider_id: definition.dig("credential_provider", "provider_id")
      )

      # Build configuration
      if definition["build_configuration"].present?
        bc = definition["build_configuration"]
        project.build_build_configuration(
          build_type: bc["build_type"],
          driver: bc["driver"],
          dockerfile_path: bc["dockerfile_path"],
          context_directory: bc["context_directory"],
          image_repository: bc["image_repository"],
          buildpack_base_builder: bc["buildpack_base_builder"],
          provider_id: bc["provider_id"],
          build_cloud_id: bc["build_cloud_id"]
        )
      end

      # Deployment configuration
      if definition["deployment_configuration"].present?
        project.build_deployment_configuration(
          deployment_method: definition.dig("deployment_configuration", "deployment_method")
        )
      end

      project.canine_config = definition
      project.save!

      context.project = project
    end
  rescue StandardError => e
    context.fail_and_return!("Failed to restore project: #{e.message}")
  end
end
