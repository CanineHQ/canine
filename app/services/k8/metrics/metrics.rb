
include StorageHelper

class K8::Metrics::Metrics
  def self.call(cluster)
    nodes = K8::Metrics::Api::Node.ls(cluster)
    metrics = []
    nodes.each do |node|
      tags = [ "node:#{node.name}" ]
      metrics << {
        metric_type: :cpu,
        tags:,
        metadata: { cpu: node.cpu_cores }
      }
      metrics << {
        metric_type: :memory,
        tags:,
        metadata: { memory: node.used_memory }
      }
      metrics << {
        metric_type: :total_cpu,
        tags:,
        metadata: { total_cpu: node.total_cpu }
      }
      metrics << {
        metric_type: :total_memory,
        tags:,
        metadata: { total_memory: node.total_memory }
      }

      node.namespaces.each do |namespace, pods|
        pods.each do |pod|
          tags = [ "node:#{node.name}", "namespace:#{namespace}", "pod:#{pod.name}" ]
          metrics << {
            metric_type: :cpu,
            tags:,
            metadata: { cpu: pod.cpu }
          }
          metrics << {
            metric_type: :memory,
            tags:,
            metadata: { memory: pod.memory }
          }
        end
      end
    end
    metrics.each do |metric|
      cluster.metrics.create(**metric)
    end
  end
end
