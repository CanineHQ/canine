class AddOns::Update
  extend LightService::Action
  expects :add_on
  promises :add_on

  executed do |context|
    add_on = context.add_on
    add_on.save
  end
end
