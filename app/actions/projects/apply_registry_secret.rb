class Projects::ApplyRegistrySecret
  extend LightService::Action
  expects :project, :kubectl

  executed do |context|
    project = context.project
    next if project.public_image?

    result = Providers::GenerateConfigJson.execute(provider: project.build_provider)
    context.fail_and_return!(result.message) if result.failure?

    secret_yaml = K8::Secrets::RegistrySecret.new(project, result.docker_config_json).to_yaml
    context.kubectl.apply_yaml(secret_yaml)
  end
end
