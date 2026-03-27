module ClustersHelper
  def cluster_layout(cluster, &block)
    render layout: 'clusters/layout', locals: { cluster: }, &block
  end

  def cluster_icon(cluster, classes: "")
    icon = if cluster.local_k3s?
             "simple-icons:k3s"
    elsif cluster.k3s?
             "devicon:k3s"
    else
             "devicon:kubernetes"
    end
    tag.iconify_icon(icon:, class: classes)
  end
end
