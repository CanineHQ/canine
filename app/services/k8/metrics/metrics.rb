
include StorageHelper

class K8::Metrics::Metrics
  def self.call(cluster)
    nodes = K8::Metrics::Api::Node.ls(cluster)
    metrics = []
    nodes.each do |node|
      metrics << {
        metric_type: :cpu,
        tags: [ node.name ],
        metadata: { cpu: node.cpu_cores }
      }
      metrics << {
        metric_type: :memory,
        tags: [ node.name ],
        metadata: { memory: node.used_memory }
      }
      metrics << {
        metric_type: :total_cpu,
        tags: [ node.name ],
        metadata: { total_cpu: node.total_cpu }
      }
      metrics << {
        metric_type: :total_memory,
        tags: [ node.name ],
        metadata: { total_memory: node.total_memory }
      }

      node.namespaces.each do |namespace, pods|
        pods.each do |pod|
          metrics << {
            metric_type: :cpu,
            tags: [ node.name, namespace, pod.name ],
            metadata: { cpu: pod.cpu }
          }
          metrics << {
            metric_type: :memory,
            tags: [ node.name, namespace, pod.name ],
            metadata: { memory: pod.memory }
          }
        end
      end
    end
    cluster.metrics.create(attributes)
  end
end
