class CanineConfig::CreateDefinition
  extend LightService::Action

  expects :source_project
  promises :definition

  executed do |context|
    context.definition = context.source_project.to_canine_config
  end
end
