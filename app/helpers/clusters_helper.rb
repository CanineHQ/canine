module ClustersHelper
  def cluster_layout(cluster, &block)
    render layout: 'clusters/layout', locals: { cluster: }, &block
  end

  def cluster_icon(cluster, classes: "")
    icon = cluster.k3s? ? "devicon:k3s" : "devicon:kubernetes"
    tag.iconify_icon(icon:, classes:)
  end
end
