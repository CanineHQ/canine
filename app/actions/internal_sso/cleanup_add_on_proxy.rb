class InternalSSO::CleanupAddOnProxy
  extend LightService::Action

  expects :add_on

  executed do |context|
    add_on = context.add_on

    next context unless add_on.installed?

    AddOns::CleanupAuthProxyJob.perform_later(add_on)
  end
end
