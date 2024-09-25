class K8::Metrics::Pods
  def self.call(cluster, selector: nil)
    K8::Kubectl.new(cluster.kubeconfig, nil).with_kube_config do |kubeconfig_file|
      command = "kubectl top pods --kubeconfig #{kubeconfig_file.path} #{selector.present? ? "-l #{selector}" : ""}"
      output = `#{command}`
      parse_output(output)
    end
  end

  private

  def self.parse_output(output)
    lines = output.split("\n")
    headers = lines.shift.split(/\s+/)
    
    lines.map do |line|
      values = line.split(/\s+/, 3)
      {
        name: values[0],
        cpu: values[1],
        memory: values[2]
      }
    end
  end
end