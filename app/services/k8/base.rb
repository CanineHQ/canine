# frozen_string_literal: true

class K8::Base
  def template_path
    class_path_parts = self.class.name.split('::').map(&:underscore)

    # Generate the file name dynamically based on the last part of the class name
    file_name = "#{class_path_parts.pop}.yaml"

    # Construct the full file path using Rails.root.join
    Rails.root.join('resources', *class_path_parts, file_name)
  end

  def to_yaml
    template_content = template_path.read
    erb_template = ERB.new(template_content)
    erb_template.result(binding)
  end

  def client
    @client ||= K8::Client.new(cluster.kubeconfig)
  end
end
