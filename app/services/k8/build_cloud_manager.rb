class K8::BuildCloudManager
  include K8::Kubeconfig
  include StorageHelper
  # Only referenced in the migration for now.
  BUILDKIT_BUILDER_DEFAULT_NAMESPACE = 'canine-k8s-builder'

  attr_reader :connection, :build_cloud

  def self.install(build_cloud)
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
      # Initialize the K8::BuildCloud service with the build_cloud model
      build_cloud_manager = K8::BuildCloudManager.new(build_cloud.cluster, build_cloud)

      # Run the setup
      build_cloud_manager.create_or_update_builder!

      # Check if builder is ready
      if build_cloud_manager.builder_ready?
        # Update build cloud record with success
        build_cloud.update!(
          status: :active,
          installed_at: Time.current,
          driver_version: build_cloud_manager.get_buildkit_version,
          installation_metadata: build_cloud.installation_metadata.merge(
            completed_at: Time.current,
            builder_ready: true
          )
        )

        Rails.logger.info("Successfully installed build cloud on cluster #{build_cloud.cluster.name}")
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

      Rails.logger.error("Failed to install build cloud on cluster #{build_cloud.cluster.name}: #{e.message}")
    end
  end

  def initialize(connection, build_cloud)
    @connection = connection
    @build_cloud = build_cloud
  end

  def ensure_active!
    # TODO: Check the pods in the namespace and ensure they are running.
    K8::Client.from_cluster(build_cloud.cluster).pods_for_namespace(build_cloud.namespace).any?
  rescue StandardError
    false
  end

  def get_buildkit_version
    local_runner = Cli::RunAndReturnOutput.new
    output = local_runner.call("docker buildx inspect #{build_cloud.name}")
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
    status = runner.call("docker buildx ls --format json")
    if status.success?
      builder_names = runner.output.split("\n").map do |x| JSON.parse(x) end.map { |x| x["Name"] }
      builder_names.include?(build_cloud.name)
    else
      false
    end
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
    if builder_ready?
      build_cloud.info("Existing builder found, removing...")
      remove_builder!
      create_builder!
    else
      create_builder!
    end
  end

  def create_local_builder!
    if ensure_active!
      create_builder!
    else
      raise "Remote builder is not active, please enable the build cloud first."
    end
  end

  def remove_local_builder!
    if ensure_active!
      `docker buildx rm --keep-daemon #{build_cloud.name}`
    else
      raise "Remote builder is not active, please enable the build cloud first."
    end
  end

  def local_builder_exists?
    local_runner = Cli::RunAndReturnOutput.new
    local_runner.call("docker buildx inspect #{build_cloud.name}")
    true
  rescue StandardError
    false
  end

  def create_builder!
    return if local_builder_exists?

    ensure_namespace!
    # Write kubeconfig to temp file for docker buildx

    # Create the buildx builder with kubernetes driver
    # The --bootstrap flag will start the builder immediately
    with_kube_config do |kubeconfig_file|
      command = "docker buildx create "
      command += "--bootstrap "
      command += "--name #{build_cloud.name} "
      command += "--driver kubernetes "
      command += "--driver-opt namespace=#{build_cloud.namespace} "
      command += "--driver-opt replicas=#{build_cloud.replicas} "
      command += "--driver-opt requests.cpu=#{integer_to_compute(build_cloud.cpu_requests)} "
      command += "--driver-opt requests.memory=#{integer_to_memory(build_cloud.memory_requests)} "
      command += "--driver-opt limits.cpu=#{integer_to_compute(build_cloud.cpu_limits)} "
      command += "--driver-opt limits.memory=#{integer_to_memory(build_cloud.memory_limits)} "

      runner.call(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
    end

    # Wait for builder to be ready
    wait_for_builder_ready!
  end

  def wait_for_builder_ready!
    max_attempts = 120
    attempts = 0

    while attempts < max_attempts
      if builder_ready?
        return true
      end

      sleep 5
      attempts += 1
    end

    raise "BuildKit builder did not become ready in time"
  end

  def ensure_builder_active!
    unless builder_ready?
      raise "BuildKit builder is not ready. Run setup! first."
    end

    # Set the builder as active
    runner.call("docker buildx use #{build_cloud.name}")
  end

  def ensure_namespace!
    # Create namespace if it doesn't exist
    with_kube_config do |kubeconfig_file|
      command = "kubectl create namespace #{namespace}"
      runner.call(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
    end
  rescue StandardError => e
    # Namespace might already exist, which is fine
    build_cloud.info("Namespace #{namespace} might already exist: #{e.message}")
  end

  def remove_builder!
    K8::Kubectl.new(connection.kubeconfig).call("delete namespace #{namespace} --ignore-not-found=true")

    # Delete locally, this also removes the builder from kubernetes
    runner.call("docker buildx rm #{build_cloud.name}")
  rescue StandardError => e
    Rails.logger.warn("Error removing builder: #{e.message}")
  end

  def runner
    @runner ||= Cli::RunAndLog.new(build_cloud)
  end

  def kubeconfig
    # This is necessary for the include K8::Kubeconfig module
    connection.kubeconfig
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
