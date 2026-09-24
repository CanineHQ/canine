# Installs KubeVirt (VMs on Kubernetes) and CDI (disk importer/cloner), which agent computers run on, then builds the
# agent computer golden image. Reuses an existing KubeVirt install and never removes one Canine didn't install.
class ClusterPackage::Installer::KubeVirt < ClusterPackage::Installer::Base
  KUBEVIRT_VERSION = "v1.9.0"
  CDI_VERSION = "v1.66.1"
  KUBEVIRT_URL = "https://github.com/kubevirt/kubevirt/releases/download/#{KUBEVIRT_VERSION}"
  CDI_URL = "https://github.com/kubevirt/containerized-data-importer/releases/download/#{CDI_VERSION}"
  MANIFESTS = [
    "#{KUBEVIRT_URL}/kubevirt-operator.yaml", "#{KUBEVIRT_URL}/kubevirt-cr.yaml",
    "#{CDI_URL}/cdi-operator.yaml", "#{CDI_URL}/cdi-cr.yaml"
  ].freeze

  def install!(kubectl)
    cluster = package.cluster

    if deployed?(kubectl)
      cluster.info("KubeVirt and CDI already installed, reusing them", color: :yellow)
    else
      MANIFESTS.each { |url| kubectl.(%W[apply -f #{url}]) }
      package.update!(config: package.config.merge("installed_by_canine" => true))
      cluster.info("Waiting for KubeVirt and CDI to become available...", color: :yellow)
      kubectl.(%w[wait kubevirt/kubevirt -n kubevirt --for=condition=Available --timeout=10m])
      kubectl.(%w[wait cdi/cdi --for=condition=Available --timeout=10m])
    end

    ensure_kvm!(kubectl)
    AgentComputers::BuildImageJob.perform_later(cluster)
  end

  def uninstall!(kubectl)
    cluster = package.cluster
    raise "Delete this cluster's agent computers before uninstalling KubeVirt" if cluster.agent_computers.exists?

    kubectl.(%W[delete namespace #{AgentComputer::Image::NAMESPACE} --ignore-not-found])
    return cluster.info("KubeVirt was installed outside Canine; leaving it in place", color: :yellow) unless package.config["installed_by_canine"]

    kubectl.(%w[delete kubevirt/kubevirt -n kubevirt --ignore-not-found --wait=true])
    kubectl.(%w[delete cdi/cdi --ignore-not-found --wait=true])
    MANIFESTS.reverse.each { |url| kubectl.(%W[delete -f #{url} --ignore-not-found]) }
  end

  private

  def deployed?(kubectl)
    kubectl.(%w[get kubevirt -A -o jsonpath={.items[*].status.phase}]).include?("Deployed") &&
      kubectl.(%w[get cdi -A -o jsonpath={.items[*].status.phase}]).include?("Deployed")
  rescue Cli::CommandFailedError
    false
  end

  # KubeVirt advertises KVM as a node resource; without it VMs would fall back to (very slow) emulation or not start
  def ensure_kvm!(kubectl)
    kvm = kubectl.(%w[get nodes -o jsonpath={.items[*].status.allocatable.devices\.kubevirt\.io/kvm}]).split
    return if kvm.any? { |count| count.to_i.positive? || count.end_with?("k") }

    raise "No node in this cluster exposes KVM (/dev/kvm). Agent computers need bare-metal nodes or VMs with nested virtualization."
  end
end
