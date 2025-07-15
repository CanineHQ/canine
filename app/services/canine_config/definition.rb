class CanineConfig::Definition
  attr_reader :definition

  def self.parse(yaml_content, base_project, pull_request)
    context = build_context(base_project, pull_request)

    parsed_content = if yaml_content.include?('<%')
      erb = ERB.new(yaml_content)
      context_binding = binding
      context.each do |key, value|
        context_binding.local_variable_set(key, value)
      end
      erb.result(context_binding)
    else
      yaml_content
    end

    new(YAML.safe_load(parsed_content))
  end

  def self.build_context(base_project, pull_request)
    {
      "cluster_id": base_project.project_fork_cluster_id,
      "cluster_name": base_project.project_fork_cluster.name,
      "project_name": "#{base_project.name}-#{pull_request.number}",
      "number": pull_request.number,
      "title": pull_request.title,
      "branch_name": pull_request.branch,
      "username": pull_request.user
    }
  end

  def initialize(definition)
    @definition = definition
  end

  def predeploy_script
    definition.dig('scripts', 'predeploy')
  end

  def postdeploy_script
    definition.dig('scripts', 'postdeploy')
  end

  def predestroy_script
    definition.dig('scripts', 'predestroy')
  end

  def postdestroy_script
    definition.dig('scripts', 'postdestroy')
  end

  def services
    definition['services'].map do |service|
      params = Service.permitted_params(ActionController::Parameters.new(service:))
      Service.new(params)
    end
  end

  def environment_variables
    definition['environment_variables'].map do |env|
      EnvironmentVariable.new(name: env['name'], value: env['value'])
    end
  end

  def to_hash
    @definition
  end
end
