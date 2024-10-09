
include StorageHelper

class K8::Metrics::Metrics
  def self.call(cluster)
    nodes = K8::Metrics::Nodes.call(cluster).map { |node| node[:name] }
    metrics = []
    K8::Kubectl.new(cluster.kubeconfig, nil).with_kube_config do |kubeconfig_file|
      nodes.each do |node|
        command = "kubectl --kubeconfig #{kubeconfig_file.path}"
        command += " get --raw /apis/metrics.k8s.io/v1beta1/nodes/#{node}"
        output = `#{command}`
        metrics << parse_output(output)
      end
    end
    metrics
  end

  private

  def self.parse_output(output)
    data = JSON.parse(output)
    {
      name: data["metadata"]["name"],
      cpu: convert_cpu_nanoseconds_to_cores(data["usage"]["cpu"]),
      memory: size_to_integer(data["usage"]["memory"])
    }
  end


  def self.convert_cpu_nanoseconds_to_cores(cpu_nanoseconds)
    (cpu_nanoseconds.to_i / 1_000_000_000.0).round(2)
  end
end
