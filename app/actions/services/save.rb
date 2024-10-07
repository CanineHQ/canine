class Services::Save
  extend LightService::Action

  expects :service

  executed do |context|
    context.service.save!
  end
end
