module AgentComputers
  # Builds the agent computer golden image on a cluster: imports the base Ubuntu image, boots it once in a builder VM
  # that runs provision.sh, then publishes the disk as a DataSource that agent computers clone from.
  class BuildImageJob < ApplicationJob
    queue_as :default

    TIMEOUT = 30.minutes
    POLL_INTERVAL = 5.seconds

    def perform(cluster, user = nil)
      image = AgentComputer::Image
      connection = K8::Connection.new(cluster, user, allow_anonymous: user.nil?)
      kubectl = K8::Kubectl.new(connection)
      logged = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))

      if image_ready?(kubectl)
        cluster.info("Agent computer image #{image.version} already built", color: :green)
        return
      end

      cluster.info("Building agent computer image #{image.version} (this takes several minutes the first time)...", color: :yellow)
      logged.apply_yaml(image.namespace_yaml)
      discard_partial_build(kubectl)
      logged.apply_yaml(image.data_volume_yaml)
      logged.apply_yaml(image.builder_secret_yaml)
      logged.apply_yaml(image.builder_vm_yaml)

      begin
        wait_for_build(cluster, kubectl)
      rescue StandardError
        discard_partial_build(kubectl)
        raise
      end

      logged.apply_yaml(image.data_source_yaml)
      kubectl.(%W[delete vm,secret #{image.builder_name} -n #{image::NAMESPACE} --ignore-not-found])
      cluster.success("Agent computer image #{image.version} is ready")
    end

    private

    # A half-provisioned disk must never be published, so every attempt starts from a fresh base image
    def discard_partial_build(kubectl)
      image = AgentComputer::Image
      kubectl.(%W[delete vm,secret #{image.builder_name} -n #{image::NAMESPACE} --ignore-not-found --wait=true])
      kubectl.(%W[delete datavolume #{image.name} -n #{image::NAMESPACE} --ignore-not-found --wait=true])
    end

    def image_ready?(kubectl)
      kubectl.(%W[get datasource #{AgentComputer::Image.name} -n #{AgentComputer::Image::NAMESPACE}])
      true
    rescue Cli::CommandFailedError
      false
    end

    def wait_for_build(cluster, kubectl)
      image = AgentComputer::Image
      deadline = TIMEOUT.from_now

      while Time.current < deadline
        console = builder_console(kubectl)
        return if console.include?(image::BUILD_OK)
        if console.include?(image::BUILD_FAILED)
          # The builder prints the tail of provision.sh's log right before the marker; shutdown noise follows it
          lines = console.lines
          marker = lines.rindex { |line| line.include?(image::BUILD_FAILED) }
          raise "Agent computer image build failed. End of provision.sh log:\n#{lines[[ marker - 40, 0 ].max...marker].join}"
        end

        phase = kubectl.(%W[get vmi #{image.builder_name} -n #{image::NAMESPACE} -o jsonpath={.status.phase}]).strip rescue ""
        raise "Agent computer builder VM ended (#{phase}) without reporting a result" if %w[Succeeded Failed].include?(phase) && console.empty?

        sleep POLL_INTERVAL
      end

      raise "Agent computer image build timed out after #{TIMEOUT.inspect}"
    end

    # The builder reports progress and its result on the serial console, which KubeVirt logs from the launcher pod
    def builder_console(kubectl)
      pod = kubectl.(%W[get pods -n #{AgentComputer::Image::NAMESPACE} -l vm.kubevirt.io/name=#{AgentComputer::Image.builder_name} -o jsonpath={.items[0].metadata.name}]).strip
      return "" if pod.empty?

      kubectl.(%W[logs -n #{AgentComputer::Image::NAMESPACE} #{pod} -c guest-console-log])
    rescue Cli::CommandFailedError
      ""
    end
  end
end
