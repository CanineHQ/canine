class Providers::CreateDockerImageProvider
  extend LightService::Action

  expects :provider
  promises :provider

  executed do |context|
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
