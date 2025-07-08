class CanineConfig::Definition
  attr_reader :definition

  def initialize(yaml_path, base_project, pull_request)
    context = {
      "cluster_id": base_project.project_fork_cluster_id,
      "cluster_name": base_project.project_fork_cluster.name,
      "project_name": "#{base_project.name}-#{pull_request.number}",
      "number": pull_request.number,
      "title": pull_request.title,
      "branch_name": pull_request.branch,
      "username": pull_request.user
    }

    content = if yaml_path.to_s.end_with?('.erb')
      erb = ERB.new(File.read(yaml_path))
      context_binding = binding
      context.each do |key, value|
        context_binding.local_variable_set(key, value)
      end
      erb.result(context_binding)
    else
      File.read(yaml_path)
    end

    @definition = YAML.load(content)
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
end
