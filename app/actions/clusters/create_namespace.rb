class Clusters::CreateNamespace
  extend LightService::Action

  expects :kubectl

  executed do |context|
    context.kubectl.apply_yaml(K8::Namespace.new(Struct.new(:name).new(Clusters::Install::DEFAULT_NAMESPACE)).to_yaml)
  end
end
