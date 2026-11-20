module AgentComputers
  # Whether a cluster can run an agent computer, checked before Canine asks it to: KubeVirt and CDI up, a node with
  # KVM, enough free memory on one of those nodes, and a default StorageClass for the disks. Without it, each of these
  # showed only as a provision or start timing out after 15 minutes, or as a raw kubectl or KubeVirt error.
  #
  #   AgentComputers::Precheck.new(computer, K8::Kubectl.new(connection)).run! { |line| computer.info(line) }
  #
  # Raises Precheck::Failed with what's wrong and what to do about it, in words for the person.
  class Precheck
    include StorageHelper

    class Failed < StandardError; end

    # On top of the guest's memory, the VM's launcher pod (QEMU, virt-launcher) takes about this much
    OVERHEAD = 512 * 1024**2

    def initialize(agent_computer, kubectl)
      @computer = agent_computer
      @kubectl = kubectl
    end

    # Each check logs a line as it passes; the first that fails raises
    def run!(&log)
      log ||= ->(_line) { }
      log.call("KubeVirt and CDI are running") if kubevirt!
      nodes = kvm_nodes!
      log.call("#{nodes.size == 1 ? "1 node can" : "#{nodes.size} nodes can"} run VMs with KVM")
      node, free = memory!(nodes)
      log.call("#{node} has #{integer_to_memory(free)} free for this computer's #{@computer.memory}")
      log.call("Disks go on the default StorageClass, #{storage_class!}")
    end

    private

    def cluster = "the cluster “#{@computer.cluster.name}”"

    def get(*args)
      JSON.parse(@kubectl.(%w[get] + args + %w[-o json]))
    rescue Cli::CommandFailedError => e
      raise Failed, "Canine couldn't read the cluster #{cluster} (#{e.message[/error: .*/i] || e.message.lines.last&.strip}). " \
                    "Check the cluster is up and Canine can reach it."
    end

    def kubevirt!
      kubevirt = get_optional("kubevirt", "-A")
      cdi = get_optional("cdi", "-A")
      missing = { "KubeVirt" => kubevirt, "CDI" => cdi }.reject { |_, items| items.any? }.keys
      if missing.any?
        raise Failed, "#{missing.join(" and ")} #{missing.one? ? "isn't" : "aren't"} installed on #{cluster}. Agent computers " \
                      "run as KubeVirt VMs, with disks imported by CDI: install the KubeVirt package on the cluster's page."
      end

      not_ready = { "KubeVirt" => kubevirt, "CDI" => cdi }.filter_map do |name, items|
        phase = items.first.dig("status", "phase")
        "#{name} (#{phase || "no status yet"})" unless phase == "Deployed"
      end
      return true if not_ready.empty?

      raise Failed, "#{not_ready.join(" and ")} #{not_ready.one? ? "isn't" : "aren't"} ready on #{cluster} yet. If it was just installed, " \
                    "give it a few minutes; otherwise check its pods (kubectl get pods -n kubevirt; -n cdi)."
    end

    # KubeVirt's or CDI's custom resources, or none if their CRD isn't there
    def get_optional(*args)
      JSON.parse(@kubectl.(%w[get] + args + %w[-o json]))["items"]
    rescue Cli::CommandFailedError
      []
    end

    # Nodes that are ready, take pods, and advertise KVM (KubeVirt's devices.kubevirt.io/kvm resource, there when the
    # node has /dev/kvm)
    def kvm_nodes!
      nodes = get("nodes")["items"].select do |node|
        ready = node.dig("status", "conditions").to_a.any? { |c| c["type"] == "Ready" && c["status"] == "True" }
        ready && !node.dig("spec", "unschedulable")
      end
      raise Failed, "None of the nodes in #{cluster} is ready to take new pods." if nodes.empty?

      kvm = nodes.select { |node| node.dig("status", "allocatable", "devices.kubevirt.io/kvm").to_i.positive? }
      return kvm if kvm.any?

      raise Failed, "None of the nodes in #{cluster} can run VMs: KubeVirt doesn't see KVM (/dev/kvm) on any of them, so " \
                    "there's no hardware virtualization for the computer.\n" \
                    "- On your own machine or a bare-metal server: turn on virtualization (Intel VT-x or AMD-V) in the " \
                    "BIOS, and check the kvm module is loaded (lsmod | grep kvm).\n" \
                    "- On a cloud VM: use an instance type with nested virtualization (or a bare-metal one), and turn it on."
    end

    # The KVM node with the most memory left after what its pods have asked for, if that's enough for the computer
    def memory!(nodes)
      needed = memory_to_integer(@computer.memory) + OVERHEAD
      requested = Hash.new(0)
      get("pods", "-A", "--field-selector=status.phase!=Succeeded,status.phase!=Failed")["items"].each do |pod|
        node = pod.dig("spec", "nodeName") or next
        requested[node] += pod.dig("spec", "containers").to_a.sum { |c| memory_to_integer(c.dig("resources", "requests", "memory").to_s) || 0 }
        requested[node] += memory_to_integer(pod.dig("spec", "overhead", "memory").to_s) || 0
      end
      free = nodes.to_h do |node|
        name = node.dig("metadata", "name")
        [ name, (memory_to_integer(node.dig("status", "allocatable", "memory").to_s) || 0) - requested[name] ]
      end
      name, most = free.max_by { |_, bytes| bytes }
      return [ name, most ] if most >= needed

      raise Failed, "There isn't enough free memory on #{cluster} for this computer: it needs #{@computer.memory} (plus about " \
                    "#{integer_to_memory(OVERHEAD)} for the VM itself), and the most any node that can run VMs has free is " \
                    "#{integer_to_memory([ most, 0 ].max)} (#{name}). Pick less memory in the computer's settings, stop " \
                    "another computer on the cluster, or add a node with more memory."
    end

    def storage_class!
      classes = get("storageclass")["items"]
      default = classes.find { |sc| sc.dig("metadata", "annotations", "storageclass.kubernetes.io/is-default-class") == "true" }
      return default.dig("metadata", "name") if default

      raise Failed, "#{cluster.capitalize} has no default StorageClass, so there's nowhere to put the computer's disks " \
                    "(#{AgentComputer::DISK_SIZE}, plus the installer). " +
                    (classes.any? ? "Mark one of #{classes.map { |sc| sc.dig("metadata", "name") }.join(", ")} as the default." :
                                    "Install one (k3s comes with local-path), and mark it as the default.")
    end
  end
end
