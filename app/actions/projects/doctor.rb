class Projects::Doctor
  extend LightService::Action
  include ActionView::RecordIdentifier

  expects :project, :user
  promises :checks

  executed do |context|
    project = context.project
    user = context.user
    checks = {}

    # Broadcast modal open
    broadcast_doctor_modal(project)

    # Run checks one by one, broadcasting each result
    checks[:cluster] = run_check(project, :cluster) { check_cluster(project, user) }
    checks[:source] = run_check(project, :source) { check_source(project) }
    checks[:registry] = run_check(project, :registry) { check_registry(project) }

    project.update_column(:doctor_checks, checks.merge(ran_at: Time.current))
    context.checks = checks
  end

  private

  def self.broadcast_doctor_modal(project)
    Turbo::StreamsChannel.broadcast_append_to(
      project,
      target: "doctor-checks",
      html: "" # Clear and signal modal to open
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

  def self.check_source(project)
    return { status: "skipped", message: "Not a git-based project" } unless project.git?
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

  def self.check_registry(project)
    provider = project.build_provider
    return { status: "skipped", message: "No registry provider configured" } if provider.blank?
    return { status: "skipped", message: "No registry credentials" } if provider.access_token.blank?

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
end
