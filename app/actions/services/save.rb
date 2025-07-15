class Services::Save
  extend LightService::Action

  expects :service

  executed do |context|
    context.service.save!
  rescue StandardError => e
    context.fail_and_return!(e.message)
  end
end
