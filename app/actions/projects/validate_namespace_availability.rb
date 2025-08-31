module Projects
  class ValidateNamespaceAvailability
    extend LightService::Action

    expects :project, :user

    executed do |context|
      project = context.project
      cluster = project.cluster

      begin
        client = K8::Client.new(K8::Connection.new(cluster, context.user))
        existing_namespaces = client.get_namespaces

        # Check if namespace already exists in Kubernetes
        namespace_exists = existing_namespaces.any? do |ns|
          ns.metadata.name == project.name && ns.metadata&.labels&.caninemanaged != "true"
        end

        if namespace_exists
          error_message = "'#{project.name}' already exists in the Kubernetes cluster. Please delete the existing namespace, or try a different name."
          project.errors.add(:name, error_message)
          context.fail_and_return!(error_message)
        end
      rescue StandardError => e
        # If we can't connect to check, we'll let it proceed and fail later if needed
        Rails.logger.warn("Could not check namespace availability: #{e.message}")
      end
    end
  end
end
