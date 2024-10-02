module ClustersHelper
  def cluster_layout(cluster, &block)
    render layout: 'clusters/layout', locals: { cluster: }, &block
  end
end
