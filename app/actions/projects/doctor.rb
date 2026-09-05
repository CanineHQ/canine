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

    # Phase 1: Open modal with discovering state
    broadcast_discovering(project)
    sleep 1

    # Phase 2: Reveal each check item one by one
    applicable.each do |name|
      broadcast_append_check(project, name)
      sleep 0.3
    end

    # Clear the discovering spinner
    broadcast_clear_discovering(project)
    sleep 0.3

    # Phase 3: Run and resolve each check
    checks = {}
    applicable.each do |name|
      checks[name] = run_check(project, name) { send(:"check_#{name}", project, user) }
    end

    context.checks = checks
  end

  private

  def self.applicable_checks(project)
    checks = [:cluster]
    checks << :source if project.git?
    checks << :registry if project.build_provider.present?
    checks << :build_cloud if project.build_configuration&.build_cloud.present?
    checks
  end

  def self.broadcast_discovering(project)
    html = '<div id="doctor-discovering" class="flex items-center gap-2 text-sm text-base-content/60">' \
           '<iconify-icon icon="lucide:loader-circle" height="16" class="text-primary animate-spin"></iconify-icon>' \
           'Analyzing project configuration...' \
           '</div>'

    Turbo::StreamsChannel.broadcast_update_to(
      project,
      target: "doctor-checks",
      html: html
    )
  end

  def self.broadcast_append_check(project, name)
    Turbo::StreamsChannel.broadcast_append_to(
      project,
      target: "doctor-checks",
      partial: "shared/doctor_check_item",
      locals: { name: name, check: { "status" => "checking", "message" => "Waiting..." } }
    )
  end

  def self.broadcast_clear_discovering(project)
    Turbo::StreamsChannel.broadcast_remove_to(
      project,
      target: "doctor-discovering"
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
      { status: "error", message: "Cannot connect to cluster" }
    end
  rescue StandardError => e
    { status: "error", message: "Cluster check failed: #{e.message}" }
  end

  def self.check_source(project, _user)
    return { status: "error", message: "No credential provider configured" } if project.project_credential_provider.blank?

    client = Git::Client.from_project(project)
    if client.repository_exists?
      { status: "ok", message: "Repository is accessible" }
    else
      { status: "error", message: "Repository not found or inaccessible" }
    end
  rescue StandardError => e
    { status: "error", message: "Source check failed: #{e.message}" }
  end

  def self.check_registry(project, _user)
    provider = project.build_provider
    return { status: "error", message: "No registry credentials" } if provider.access_token.blank?

    DockerCli.with_registry_auth(
      registry_url: provider.registry_base_url,
      username: provider.username,
      password: provider.access_token
    ) { }

    { status: "ok", message: "Registry is reachable and authenticated" }
  rescue DockerCli::AuthenticationError => e
    { status: "error", message: "Registry authentication failed: #{e.message}" }
  rescue StandardError => e
    { status: "error", message: "Registry check failed: #{e.message}" }
  end

  def self.check_build_cloud(project, user)
    build_cloud = project.build_configuration.build_cloud
    return { status: "error", message: "Build cloud is #{build_cloud.status}" } unless build_cloud.active?

    connection = K8::Connection.new(project, user)
    manager = K8::BuildCloudManager.new(connection, build_cloud)
    if manager.remote_builder_active?
      { status: "ok", message: "Build cloud is active and pods are running" }
    else
      { status: "error", message: "Build cloud pods are not running" }
    end
  rescue StandardError => e
    { status: "error", message: "Build cloud check failed: #{e.message}" }
  end
end
