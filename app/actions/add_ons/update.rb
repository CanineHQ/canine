class AddOns::Update
  extend LightService::Action
  expects :add_on
  promises :add_on

  executed do |context|
    add_on = context.add_on
    context.fail_and_return!(add_on.errors.full_messages.to_sentence) unless add_on.save
  end
end
