
include StorageHelper

class K8::Metrics::Metrics
  def self.call(connection)
    nodes = K8::Metrics::Api::Node.ls(connection)
    metrics = []
    nodes.each do |node|
      tags = [ "node:#{node.name}" ]
      metrics << {
        metric_type: :cpu,
        tags:,
        metadata: { cpu: node.cpu_cores, total_cpu: node.total_cpu }
      }
      metrics << {
        metric_type: :memory,
        tags:,
        metadata: { memory: node.used_memory, total_memory: node.total_memory }
      }

      node.namespaces.each do |namespace, pods|
        pods.each do |pod|
          tags = [ "node:#{node.name}", "namespace:#{namespace}", "pod:#{pod.name}" ]
          metrics << {
            metric_type: :cpu,
            tags:,
            metadata: { cpu: pod.cpu, total_cpu: node.total_cpu }
          }
          metrics << {
            metric_type: :memory,
            tags:,
            metadata: { memory: pod.memory, total_memory: node.total_memory }
          }
        end
      end
    end
    cluster = connection.cluster
    metrics.each do |metric|
      cluster.metrics.create(**metric)
    end
  end
end
