class K8::BuildCloudManager
  include StorageHelper
  # Only referenced in the migration for now.
  BUILDKIT_BUILDER_DEFAULT_NAMESPACE = 'canine-k8s-builder'
  READY_MAX_ATTEMPTS = 120
  READY_POLL_INTERVAL = 5 # seconds
  WARNING_CHECK_INTERVAL = 6 # check every 6 attempts (30 seconds)

  attr_reader :connection, :build_cloud

  def self.install(build_cloud, connection)
    if build_cloud.pending? || build_cloud.failed?
      build_cloud.update(error_message: nil, status: :installing)
    else
      build_cloud.update(error_message: nil, status: :updating)
    end

    params = {
      installation_metadata: {
        started_at: Time.current,
        builder_name: build_cloud.name
      }
    }

    begin
      build_cloud.info("Starting build cloud installation on cluster #{build_cloud.cluster.name}")
      build_cloud.info("Builder name: #{build_cloud.name}")
      build_cloud.info("Namespace: #{build_cloud.namespace}")
      build_cloud.info("Configuration: #{build_cloud.replicas} replicas, CPU #{integer_to_compute(build_cloud.cpu_requests)}/#{integer_to_compute(build_cloud.cpu_limits)}, Memory #{integer_to_memory(build_cloud.memory_requests)}/#{integer_to_memory(build_cloud.memory_limits)}")

      # Initialize the K8::BuildCloud service with the build_cloud model
      build_cloud_manager = K8::BuildCloudManager.new(
        connection,
        build_cloud,
      )

      # Run the setup
      build_cloud_manager.create_or_update_builder!

      build_cloud.info("Verifying builder is ready...")

      # Check if builder is ready
      if build_cloud_manager.builder_ready?
        version = build_cloud_manager.get_buildkit_version
        # Update build cloud record with success
        build_cloud.update!(
          status: :active,
          installed_at: Time.current,
          driver_version: version,
          installation_metadata: build_cloud.installation_metadata.merge(
            completed_at: Time.current,
            builder_ready: true
          )
        )

        build_cloud.success("Build cloud installed successfully!")
        build_cloud.info("BuildKit version: #{version}")
      else
        raise "Builder was created but is not ready"
      end
    rescue StandardError => e
      # Update build cloud record with failure
      build_cloud.update!(
        status: :failed,
        error_message: e.message,
        installation_metadata: build_cloud.installation_metadata.merge(
          failed_at: Time.current,
          error_details: {
            message: e.message,
            backtrace: e.backtrace&.first(5)
          }
        )
      )

      build_cloud.error("Installation failed: #{e.message}")
      raise e
    end
  end

  def initialize(connection, build_cloud)
    @connection = connection
    @build_cloud = build_cloud
  end

  def remote_builder_active?
    pods = K8::Client.new(connection).pods_for_namespace(build_cloud.namespace)
    return false if pods.empty?

    pods.all? { |pod| pod.status.phase == "Running" }
  end

  def get_buildkit_version
    local_runner = Cli::RunAndReturnOutput.new
    output = local_runner.call(%w[docker buildx inspect] + [ build_cloud.name ])
    if output
      result = parse_inspect_output(output)
      result[:version]
    else
      "unknown"
    end
  rescue StandardError
    "unknown"
  end

  def namespace
    build_cloud.namespace
  end

  # Check if the builder is ready and running
  def builder_ready?
    quiet_runner = Cli::RunAndReturnOutput.new
    output = quiet_runner.call(%w[docker buildx ls --format json])
    builders = output.split("\n").map { |x| JSON.parse(x) }
    builder = builders.find { |x| x["Name"] == build_cloud.name }
    return false unless builder

    # Verify at least one node is running, not just registered
    nodes = builder["Nodes"] || []
    nodes.any? { |n| n["Status"] == "running" }
  rescue StandardError
    false
  end

  # Build and push image using BuildKit in Kubernetes
  # @param build [Build] The build object for logging
  # @param repository_path [String] Path to the cloned repository
  # @param project [Project] The project being built
  def build_image(build, repository_path, project)
    ensure_builder_active!

    build_command = construct_buildx_command(project, repository_path)
    execute_build(build_command, build)
  end

  def create_or_update_builder!
    cleanup_stale_resources!
    create_builder!
  end

  def create_local_builder!
    if remote_builder_active?
      create_builder!
    else
      raise "Remote builder is not active, please enable the build cloud first."
    end
  end

  def remove_local_builder!
    if remote_builder_active?
      local_runner = Cli::RunAndReturnOutput.new
      local_runner.call(%w[docker buildx rm --keep-daemon] + [ build_cloud.name ])
    else
      raise "Remote builder is not active, please enable the build cloud first."
    end
  end

  def local_builder_exists?
    local_runner = Cli::RunAndReturnOutput.new
    local_runner.call(%w[docker buildx inspect] + [ build_cloud.name ])
    true
  rescue StandardError
    false
  end

  def create_builder!
    return if local_builder_exists?

    build_cloud.info("Creating namespace #{namespace}...")
    ensure_namespace!

    # Create the buildx builder with kubernetes driver and bootstrap it
    K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: connection.cluster.skip_tls_verify) do |kubeconfig_file|
      build_cloud.info("Creating BuildKit builder with #{build_cloud.replicas} replicas...")
      command = %w[docker buildx create]
      command += [ "--name", build_cloud.name ]
      command += [ "--driver", "kubernetes" ]
      command += [ "--driver-opt", "namespace=#{build_cloud.namespace}" ]
      command += [ "--driver-opt", "replicas=#{build_cloud.replicas}" ]
      command += [ "--driver-opt", "requests.cpu=#{integer_to_compute(build_cloud.cpu_requests)}" ]
      command += [ "--driver-opt", "requests.memory=#{integer_to_memory(build_cloud.memory_requests)}" ]
      command += [ "--driver-opt", "limits.cpu=#{integer_to_compute(build_cloud.cpu_limits)}" ]
      command += [ "--driver-opt", "limits.memory=#{integer_to_memory(build_cloud.memory_limits)}" ]

      runner.call(command, envs: { "KUBECONFIG" => kubeconfig_file.path })

      # Bootstrap the builder to create the pods (don't wait for it to finish — we poll ourselves)
      build_cloud.info("Bootstrapping builder pods...")
      Cli::RunAndReturnOutput.new.call(
        %w[docker buildx inspect --bootstrap] + [ build_cloud.name ],
        envs: { "KUBECONFIG" => kubeconfig_file.path }
      )
    rescue Cli::CommandFailedError => e
      # Bootstrap may fail with a timeout, but pods could still be starting
      build_cloud.warn("Bootstrap returned an error (pods may still be starting): #{e.message}")
    end

    # Wait for builder to be ready
    build_cloud.info("Waiting for builder to become ready...")
    wait_for_builder_ready!
  end

  def wait_for_builder_ready!
    attempts = 0
    logged_warnings = Set.new

    while attempts < READY_MAX_ATTEMPTS
      if builder_ready?
        build_cloud.success("Builder is ready! All pods are running.")
        return true
      end

      # Periodically log pod status and check for warnings
      if (attempts % WARNING_CHECK_INTERVAL).zero?
        log_pod_status
        check_pod_warnings(logged_warnings)
      end

      sleep READY_POLL_INTERVAL
      attempts += 1
    end

    log_pod_status
    check_pod_warnings(logged_warnings)
    raise "BuildKit builder did not become ready in time (waited #{READY_MAX_ATTEMPTS * READY_POLL_INTERVAL / 60} minutes)"
  end

  def ensure_builder_active!
    unless builder_ready?
      raise "BuildKit builder is not ready. Run setup! first."
    end

    # Set the builder as active
    runner.call(%w[docker buildx use] + [ build_cloud.name ])
  end

  def ensure_namespace!
    # Create namespace if it doesn't exist
    quiet_runner = Cli::RunAndReturnOutput.new
    K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: connection.cluster.skip_tls_verify) do |kubeconfig_file|
      quiet_runner.call(%w[kubectl create namespace] + [ namespace ], envs: { "KUBECONFIG" => kubeconfig_file.path })
    end
    build_cloud.success("Namespace #{namespace} created")
  rescue StandardError => e
    # Namespace might already exist, which is fine
    build_cloud.info("Namespace #{namespace} already exists")
  end

  def cleanup_stale_resources!
    build_cloud.info("Cleaning up stale resources in namespace #{namespace}...")
    K8::Kubectl.new(connection).call(%w[delete all --all --ignore-not-found=true] + [ "-n", namespace ])

    if local_builder_exists?
      build_cloud.info("Removing stale local builder registration...")
      Cli::RunAndReturnOutput.new.call(%w[docker buildx rm] + [ build_cloud.name ])
    end
  rescue StandardError => e
    build_cloud.warn("Failed to clean up stale resources: #{e.message}")
  end

  def remove_builder!
    K8::Kubectl.new(connection).call(%w[delete namespace] + [ namespace, "--ignore-not-found=true" ])

    # Delete locally, this also removes the builder from kubernetes
    runner.call(%w[docker buildx rm] + [ build_cloud.name ])
  rescue StandardError => e
    Rails.logger.warn("Error removing builder: #{e.message}")
  end

  def log_pod_status
    quiet_runner = Cli::RunAndReturnOutput.new
    K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: connection.cluster.skip_tls_verify) do |kubeconfig_file|
      output = quiet_runner.call(
        %w[kubectl get pods -o json] + [ "-n", namespace ],
        envs: { "KUBECONFIG" => kubeconfig_file.path }
      )
      pods = JSON.parse(output)
      (pods["items"] || []).each do |pod|
        name = pod.dig("metadata", "name")
        phase = pod.dig("status", "phase")
        ready = pod.dig("status", "containerStatuses")&.all? { |c| c["ready"] }
        status_text = ready ? "Ready" : phase
        build_cloud.info("Pod #{name}: #{status_text}")
      end

      total = (pods["items"] || []).size
      ready_count = (pods["items"] || []).count { |p| p.dig("status", "containerStatuses")&.all? { |c| c["ready"] } }
      build_cloud.info("Pods ready: #{ready_count}/#{total} (need #{build_cloud.replicas})")
    end
  rescue StandardError => e
    Rails.logger.debug("Failed to check pod status: #{e.message}")
  end

  def check_pod_warnings(logged_warnings)
    kubectl = Cli::RunAndReturnOutput.new
    K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: connection.cluster.skip_tls_verify) do |kubeconfig_file|
      output = kubectl.call(
        %w[kubectl get events --field-selector type=Warning -o json] + [ "-n", namespace ],
        envs: { "KUBECONFIG" => kubeconfig_file.path }
      )
      events = JSON.parse(output)
      (events["items"] || []).each do |event|
        message = "#{event.dig("reason")}: #{event.dig("message")}"
        unless logged_warnings.include?(message)
          logged_warnings.add(message)
          build_cloud.warn(message)
        end
      end
    end
  rescue StandardError => e
    Rails.logger.debug("Failed to check pod warnings: #{e.message}")
  end

  def runner
    @runner ||= Cli::RunAndLog.new(build_cloud)
  end

  def parse_inspect_output(text)
    version = nil

    text.each_line do |line|
      if line.start_with?("BuildKit version:")
        version = line.split(":", 2)[1].strip
        break
      end
    end

    { "version" => version }.with_indifferent_access
  end
end
