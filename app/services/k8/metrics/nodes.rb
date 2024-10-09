class K8::Metrics::Nodes
  def self.call(cluster)
    K8::Kubectl.new(cluster.kubeconfig, nil).with_kube_config do |kubeconfig_file|
      command = "kubectl top nodes --kubeconfig #{kubeconfig_file.path}"
      output = `#{command}`
      parse_output(output)
    end
  end

  private

  def self.parse_output(output)
    # Define a regex pattern to capture the required fields
    pattern = /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/

    # Split the data into lines and remove the header line
    lines = output.split("\n")
    lines.shift # Remove the header line

    # Parse each line and create a hash for each node
    parsed_data = lines.map do |line|
      match = pattern.match(line)
      if match
        {
          name: match[1],
          cpu_cores: match[2],
          cpu_percent: match[3],
          memory_bytes: match[4],
          memory_percent: match[5]
        }
      else
        {}
      end
    end
    parsed_data
  end
end
