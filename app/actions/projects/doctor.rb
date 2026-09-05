class Projects::Doctor
  extend LightService::Action
  include ActionView::RecordIdentifier

  expects :project, :user
  promises :checks

  executed do |context|
    project = context.project
    user = context.user

    # Determine which checks are applicable
    applicable = applicable_checks(project)

    # Show all check items immediately
    applicable.each do |name|
      broadcast_append_check(project, name)
    end

    # Run and resolve each check
    checks = {}
    applicable.each do |name|
      checks[name] = run_check(project, name) { send(:"check_#{name}", project, user) }
    end

    context.checks = checks

    broadcast_summary(project, checks)
  end

  private

  def self.applicable_checks(project)
    checks = [ :cluster ]
    if project.git?
      checks << :source
      checks << :registry if project.build_provider.present?
      checks << :build_cloud if project.build_configuration&.build_cloud.present?
    else
      checks << :image
    end
    checks
  end

  def self.broadcast_append_check(project, name)
    Turbo::StreamsChannel.broadcast_append_to(
      project,
      target: "doctor-checks",
      partial: "shared/doctor_check_item",
      locals: { name: name, check: { "status" => "checking", "message" => "Waiting..." } }
    )
  end

  def self.broadcast_summary(project, checks)
    total_count = checks.values.size
    failed_count = checks.values.count { |c| c[:status] == "error" }

    Turbo::StreamsChannel.broadcast_append_to(
      project,
      target: "doctor-checks",
      partial: "shared/doctor_summary",
      locals: { total_count: total_count, failed_count: failed_count }
    )
  end

  def self.run_check(project, name)
    # Broadcast "checking" state
    Turbo::StreamsChannel.broadcast_replace_to(
      project,
      target: "doctor-check-#{name}",
      partial: "shared/doctor_check_item",
      locals: { name: name, check: { "status" => "checking", "message" => "Checking..." } }
    )

    sleep 0.5 # Brief pause for visual effect

    result = yield

    # Broadcast result
    Turbo::StreamsChannel.broadcast_replace_to(
      project,
      target: "doctor-check-#{name}",
      partial: "shared/doctor_check_item",
      locals: { name: name, check: result.stringify_keys }
    )

    sleep 0.3

    result
  end

  def self.check_cluster(project, user)
    connection = K8::Connection.new(project, user)
    client = K8::Client.new(connection)
    if client.can_connect?
      { status: "ok", message: "Cluster is reachable" }
    else
      { status: "error", message: "Cannot connect to cluster",
        hint: "Verify the cluster is running and the kubeconfig is correct. Check the cluster settings page for connection details." }
    end
  rescue StandardError => e
    { status: "error", message: "Cluster check failed: #{e.message}",
      hint: "Ensure the cluster endpoint is reachable and credentials haven't expired. Try reconnecting the cluster." }
  end

  def self.check_source(project, _user)
    if project.project_credential_provider.blank?
      return { status: "error", message: "No credential provider configured",
               hint: "Add a Git credential provider (GitHub, GitLab, or Bitbucket) in your project settings." }
    end

    client = Git::Client.from_project(project)
    if client.repository_exists?
      { status: "ok", message: "Repository is accessible" }
    else
      { status: "error", message: "Repository not found or inaccessible",
        hint: "Check the repository URL is correct and the credential provider has access to it. The token may have expired or been revoked." }
    end
  rescue StandardError => e
    { status: "error", message: "Source check failed: #{e.message}",
      hint: "Verify your Git provider credentials are still valid and the repository URL is correct." }
  end

  def self.check_registry(project, _user)
    provider = project.build_provider
    if provider.access_token.blank?
      return { status: "error", message: "No registry credentials",
               hint: "Add registry credentials to your build configuration or credential provider." }
    end

    DockerCli.with_registry_auth(
      registry_url: provider.registry_base_url,
      username: provider.username,
      password: provider.access_token
    ) { }

    { status: "ok", message: "Registry is reachable and authenticated" }
  rescue DockerCli::AuthenticationError => e
    { status: "error", message: "Registry authentication failed: #{e.message}",
      hint: "The registry credentials are invalid. Regenerate your access token and update it in your provider settings." }
  rescue StandardError => e
    { status: "error", message: "Registry check failed: #{e.message}",
      hint: "Ensure the registry URL is correct and the registry service is available." }
  end

  def self.check_image(project, _user)
    image = project.full_image_name
    tag = project.branch.presence || "latest"
    full_ref = "#{image}:#{tag}"

    if project.public_image?
      _, _, status = Open3.capture3("docker", "manifest", "inspect", full_ref)
    else
      provider = project.project_credential_provider&.provider
      if provider.blank?
        return { status: "error", message: "No credential provider configured",
                 hint: "Add a container registry credential provider to pull private images." }
      end

      DockerCli.with_registry_auth(
        registry_url: provider.registry_base_url,
        username: provider.username,
        password: provider.access_token
      ) do
        _, _, status = Open3.capture3("docker", "manifest", "inspect", full_ref)
      end
    end

    if status.success?
      { status: "ok", message: "Image #{full_ref} is accessible" }
    else
      { status: "error", message: "Image #{full_ref} not found",
        hint: "Verify the image name and tag exist in the registry. Check that credentials have pull access." }
    end
  rescue DockerCli::AuthenticationError => e
    { status: "error", message: "Registry authentication failed: #{e.message}",
      hint: "The registry credentials are invalid. Update them in your provider settings." }
  rescue StandardError => e
    { status: "error", message: "Image check failed: #{e.message}",
      hint: "Ensure Docker is available and the registry is reachable." }
  end

  def self.check_build_cloud(project, user)
    build_cloud = project.build_configuration.build_cloud
    unless build_cloud.active?
      return { status: "error", message: "Build cloud is #{build_cloud.status}",
               hint: "The build cloud needs to be in active status. Try reinstalling it from the cluster settings page." }
    end

    connection = K8::Connection.new(project, user)
    manager = K8::BuildCloudManager.new(connection, build_cloud)
    if manager.remote_builder_active?
      { status: "ok", message: "Build cloud is active and pods are running" }
    else
      { status: "error", message: "Build cloud pods are not running",
        hint: "The builder pods may have been evicted or crashed. Try reinstalling the build cloud from the cluster settings." }
    end
  rescue StandardError => e
    { status: "error", message: "Build cloud check failed: #{e.message}",
      hint: "Check that the cluster is reachable and the build cloud namespace still exists." }
  end
end
