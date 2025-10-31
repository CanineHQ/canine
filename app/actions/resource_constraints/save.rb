class ResourceConstraints::Save
  extend LightService::Action

  expects :resource_constraint

  executed do |context|
    context.resource_constraint.save!
  rescue StandardError => e
    context.fail_and_return!(e.message)
  end
end
