class ProjectForks::CreateDefinition
  extend LightService::Action

  expects :parent_project, :pull_request
  promises :definition

  executed do |context|
    parent = context.parent_project
    pr = context.pull_request

    # Start from parent's full definition for infra (credentials, build/deploy config)
    definition = parent.to_canine_config

    # Override fork-specific project attrs
    definition["project"]["name"] = "#{parent.name}-#{pr.number}"
    definition["project"]["branch"] = pr.branch

    # Fetch .canine.yml from the PR branch
    client = Git::Client.from_project(parent)
    file = client.get_file('.canine.yml', pr.branch) || client.get_file('.canine.yml.erb', pr.branch)

    if file.present?
      canine_config = CanineConfig::Definition.parse(file.content, parent, pr)
      config_hash = canine_config.to_hash

      # Replace child record and script sections with .canine.yml content
      definition.merge!(
        "scripts" => config_hash["scripts"],
        "services" => config_hash["services"] || [],
        "environment_variables" => config_hash["environment_variables"] || [],
        "volumes" => config_hash["volumes"] || [],
        "notifiers" => config_hash["notifiers"] || []
      )
      definition.delete("scripts") if definition["scripts"].blank?
    else
      # No .canine.yml — no child records or scripts
      definition.delete("scripts")
      definition["services"] = []
      definition["environment_variables"] = []
      definition["volumes"] = []
      definition["notifiers"] = []
    end

    context.definition = definition
  end
end
