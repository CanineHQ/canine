class AddOns::Save
  extend LightService::Action
  expects :add_on

  executed do |context|
    unless context.add_on.save
      context.fail_and_return!("Failed to create add on")
    end
  end
end
