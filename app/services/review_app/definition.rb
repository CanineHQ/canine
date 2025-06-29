class ReviewApp::Definition
  def initialize(yaml_path, context = {})
    content = if yaml_path.end_with?('.erb')
      require 'erb'
      erb = ERB.new(File.read(yaml_path))
      context_binding = binding
      context.each { |key, value| context_binding.local_variable_set(key, value) }
      erb.result(context_binding)
    else
      File.read(yaml_path)
    end

    @definition = YAML.load(content)
  end

  def to_yaml
    {
      name: @project.name
    }
  end
end
