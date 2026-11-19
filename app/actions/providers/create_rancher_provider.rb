class Providers::CreateRancherProvider
  extend LightService::Action

  expects :provider
  promises :provider

  executed do |context|
    context.provider.save!
  end
end
