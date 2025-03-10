class Clusters::Save
  extend LightService::Action
  expects :cluster

  executed do |context|
    context.cluster.save!
  end
end
