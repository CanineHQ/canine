namespace :metrics do
  desc "Poll Kubernetes cluster metrics"
  task nodes: :environment do
    Cluster.running.each do |cluster|
      nodes = K8::Metrics::Metrics.call(cluster)
      attributes = nodes.flat_map do |node|
        [
          {
            metric_type: :cpu,
            tags: [ node[:name] ],
            metadata: {
              cpu: node[:cpu]
            }
          },
          {
            metric_type: :memory,
            tags: [ node[:name] ],
            metadata: {
              memory: node[:memory]
            }
          }
        ]
      end

      cluster.metrics.create(attributes)
    end
  end

  desc "flush metrics"
  task flush: :environment do |_, args|
    Metric.where("created_at < ?", 1.days.ago).destroy_all
  end
end
