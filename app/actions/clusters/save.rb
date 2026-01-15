class Clusters::Save
  extend LightService::Action
  expects :cluster

  executed do |context|
    unless context.cluster.save
      context.fail_and_return!(context.cluster.errors.full_messages.join(", "))
    end
  end
end
