module AgentComputers
  # Creates an agent computer: a KubeVirt VM whose disk is cloned from the cluster's golden image.
  class ProvisionJob < ApplicationJob
    queue_as :default

    READY_TIMEOUT = 15.minutes
    POLL_INTERVAL = 5.seconds
    FAILURE_GRACE = 3.minutes

    def perform(agent_computer)
      agent_computer.provisioning!

      cluster = agent_computer.cluster
      user = agent_computer.user
      connection = K8::Connection.new(cluster, user)
      kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))

      # No-op when this cluster already has the current image version
      BuildImageJob.perform_now(cluster, user)

      kubectl.apply_yaml(K8::Namespace.new(agent_computer).to_yaml)
      kubectl.apply_yaml(build_network_policy_yaml(agent_computer))
      kubectl.apply_yaml(AgentComputer::Image.clone_role_yaml)
      kubectl.apply_yaml(AgentComputer::Image.clone_role_binding_yaml(agent_computer))
      kubectl.apply_yaml(build_virtual_machine_yaml(agent_computer))

      wait_until_running(agent_computer, K8::Kubectl.new(connection))
      agent_computer.running!
    rescue StandardError => e
      agent_computer.failed!
      Rails.logger.error("Failed to provision agent computer #{agent_computer.id}: #{e.message}")
      raise
    end

    private

    # Covers cloning the disk and booting; KubeVirt reports problems like a failed clone as a Failure condition
    def wait_until_running(agent_computer, kubectl)
      started = Time.current
      deadline = started + READY_TIMEOUT
      while Time.current < deadline
        vm = JSON.parse(kubectl.(%W[get vm #{agent_computer.name} -n #{agent_computer.namespace} -o json]))
        return if vm.dig("status", "printableStatus") == "Running"

        # A failure can be stale from an earlier attempt (e.g. before the clone permission existed), so give
        # KubeVirt's backoff time to retry before trusting it
        failure = vm.dig("status", "conditions")&.find { |c| c["type"] == "Failure" && c["status"] == "True" }
        raise "Agent computer VM failed to start: #{failure["message"]}" if failure && Time.current > started + FAILURE_GRACE

        sleep POLL_INTERVAL
      end
      raise "Agent computer VM wasn't running after #{READY_TIMEOUT.inspect}"
    end

    def labels(agent_computer)
      {
        "agent-computer" => agent_computer.name,
        "app.kubernetes.io/managed-by" => "canine"
      }
    end

    # Selkies and computer-server are unauthenticated, so block every in-cluster connection. Canine reaches the VM
    # through kubectl port-forward, which isn't subject to NetworkPolicy. The image namespace is allowed because CDI
    # clones the golden disk over the network, from a pod there to a pod here.
    def build_network_policy_yaml(agent_computer)
      {
        "apiVersion" => "networking.k8s.io/v1",
        "kind" => "NetworkPolicy",
        "metadata" => { "name" => "deny-ingress-except-image-clone", "namespace" => agent_computer.namespace },
        "spec" => {
          "podSelector" => {},
          "policyTypes" => [ "Ingress" ],
          "ingress" => [
            { "from" => [ { "namespaceSelector" => { "matchLabels" => { "kubernetes.io/metadata.name" => AgentComputer::Image::NAMESPACE } } } ] }
          ]
        }
      }.to_yaml
    end

    def build_virtual_machine_yaml(agent_computer)
      {
        "apiVersion" => "kubevirt.io/v1",
        "kind" => "VirtualMachine",
        "metadata" => {
          "name" => agent_computer.name,
          "namespace" => agent_computer.namespace,
          "labels" => labels(agent_computer)
        },
        "spec" => {
          "runStrategy" => "Always",
          "dataVolumeTemplates" => [
            {
              "metadata" => { "name" => "#{agent_computer.name}-root" },
              "spec" => {
                "sourceRef" => { "kind" => "DataSource", "name" => AgentComputer::Image.name, "namespace" => AgentComputer::Image::NAMESPACE },
                # CDI's StorageProfile for local-path has no default access mode, so always spell these out
                "storage" => {
                  "accessModes" => [ "ReadWriteOnce" ],
                  "volumeMode" => "Filesystem",
                  "resources" => { "requests" => { "storage" => AgentComputer::DISK_SIZE } }
                }
              }
            }
          ],
          "template" => {
            "metadata" => { "labels" => labels(agent_computer) },
            "spec" => {
              "terminationGracePeriodSeconds" => 30,
              "domain" => {
                "cpu" => { "cores" => AgentComputer::CPU_CORES },
                "memory" => { "guest" => AgentComputer::MEMORY },
                "devices" => {
                  "logSerialConsole" => true,
                  "disks" => [
                    { "name" => "root", "disk" => { "bus" => "virtio" } },
                    { "name" => "cloudinit", "disk" => { "bus" => "virtio" } }
                  ],
                  "interfaces" => [ { "name" => "default", "masquerade" => {} } ]
                }
              },
              "networks" => [ { "name" => "default", "pod" => {} } ],
              "volumes" => [
                { "name" => "root", "dataVolume" => { "name" => "#{agent_computer.name}-root" } },
                { "name" => "cloudinit", "cloudInitNoCloud" => { "userData" => "#cloud-config\nhostname: #{agent_computer.name}\n" } }
              ]
            }
          }
        }
      }.to_yaml
    end
  end
end
