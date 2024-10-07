class K8::Metrics::Nodes
  def self.call(cluster)
    K8::Kubectl.new(cluster.kubeconfig, nil).with_kube_config do |kubeconfig_file|
      command = "kubectl get nodes -o json --kubeconfig #{kubeconfig_file.path}"
      output = `#{command}`
      parse_output(output)
    end
  end

  private

  def self.parse_output(output)
    data = JSON.parse(output)
    data["items"].map do |node|
      {
        name: node.dig("metadata", "name"),
        cpu_cores: node.dig("status", "capacity", "cpu"),
        cpu_percent: node.dig("status", "allocatable", "cpu"),
        memory_bytes: node.dig("status", "capacity", "memory"),
        memory_percent: node.dig("status", "allocatable", "memory")
      }
    end
  end
end
