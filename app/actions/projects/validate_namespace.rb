module Projects
  class ValidateNamespace
    extend LightService::Action

    expects :project, :user

    def self.validate_namespace_does_not_exist_or_is_managed(
      context,
      project,
      client,
      existing_namespaces
    )
      namespace_exists = existing_namespaces.any? do |ns|
        ns.metadata.name == project.namespace && ns.metadata&.labels&.caninemanaged != "true"
      end
      if namespace_exists
        error_message = "Namespace `#{project.name}` already exists in the Kubernetes cluster. Please delete the existing namespace, or try a different name."
        project.errors.add(:name, error_message)
        context.fail_and_return!(error_message)
      end
    end

    def self.validate_namespace_exists(
      context,
      project,
      client,
      existing_namespaces
    )
      existing_namespace = existing_namespaces.any? do |ns|
        ns.metadata.name == project.namespace
      end
      unless existing_namespace
        error_message = "`#{project.name}` does not exist in the cluster. If you want Canine to automaticaly create it, enable <b>auto create namespace</b>"
        project.errors.add(:base, error_message)
        context.fail_and_return!(error_message)
      end
    end

    executed do |context|
      project = context.project
      cluster = project.cluster

      begin
        client = K8::Client.new(K8::Connection.new(cluster, context.user))
        existing_namespaces = client.get_namespaces

        if project.managed_namespace
          validate_namespace_does_not_exist_or_is_managed(context, project, client, existing_namespaces)
        else
          validate_namespace_exists(context, project, client, existing_namespaces)
        end
      rescue StandardError => e
        # If we can't connect to check, we'll let it proceed and fail later if needed
        Rails.logger.warn("Could not check namespace availability: #{e.message}")
      end
    end
  end
end
