class Namespaced::SetUpNamespace
  extend LightService::Action
  expects :namespaced
  promises :namespaced

  executed do |context|
    namespaced = context.namespaced
    if namespaced.namespace.blank? && namespaced.managed_namespace
      # autoset the namespace to the namespaced name
      namespaced.namespace = namespaced.name
    elsif namespaced.namespace.blank? && !namespaced.managed_namespace
      namespaced.errors.add(:base, "A namespace must be provided if it is not managed by Canine")
      context.fail_and_return!("Failed to set up namespace")
    end
  end
end
