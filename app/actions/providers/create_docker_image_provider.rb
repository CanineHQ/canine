class Providers::CreateDockerImageProvider
  extend LightService::Action

  expects :provider
  promises :provider

  executed do |context|
    provider = context.provider

    # Test the container registry credentials
    begin
      DockerCli.with_registry_auth(
        registry_url: provider.registry_base_url,
        username: provider.username_param,
        password: provider.access_token
      ) do
        # If we get here, authentication was successful
        Rails.logger.info("Container registry authentication successful")
      end
    rescue DockerCli::AuthenticationError => e
      context.provider.errors.add(:access_token, "Invalid credentials: #{e.message}")
      context.fail_and_return!(e.message)
    end

    context.provider.auth = {
      info: {
        username: context.provider.username_param
      }
    }.to_json

    if context.provider.save
      context.provider = context.provider
    else
      context.provider.errors.add(:base, "Failed to create provider")
      context.fail_and_return!("Failed to create provider")
    end
  end
end
