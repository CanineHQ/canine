class K8::Metrics::Pods
  def self.call(cluster, selector: nil)
    K8::Kubectl.new(cluster.kubeconfig, nil).with_kube_config do |kubeconfig_file|
      command = "kubectl get pods --kubeconfig #{kubeconfig_file.path} -o json #{selector.present? ? "-l #{selector}" : ""}"
      output = `#{command}`
      parse_output(output)
    end
  end

  private

  def self.parse_output(output)
    data = JSON.parse(output)
    pods_info = data["items"].map do |pod|
      {
        name: pod["metadata"]["name"],
        cpu: pod["spec"]["containers"][0]["resources"]["requests"]["cpu"],
        memory: pod["spec"]["containers"][0]["resources"]["requests"]["memory"]
      }
    end
  end
end
