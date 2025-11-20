# frozen_string_literal: true

class K8::Base
  attr_reader :connection

  def connect(connection)
    @connection = connection
    self
  end

  def connected?
    connection.present?
  end

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
    result = erb_template.result(binding)
    result.gsub(/\n\s*\n/, "\n")
  end

  def self.manifest_key(yaml)
    manifest = YAML.safe_load(yaml)
    kind = manifest["kind"]&.downcase
    name = manifest.dig("metadata", "name")
    manifest_key = "#{kind}/#{name}"
  end

  def suggested_file_name
    "#{K8::Base.manifest_key(to_yaml).gsub("/", "_").underscore}.yaml"
  end

  def client
    raise "Client not connected" unless connected?
    @client ||= K8::Client.new(connection)
  end

  def kubectl
    raise "Kubectl not connected" unless connected?
    @kubectl ||= K8::Kubectl.new(connection)
  end
end
