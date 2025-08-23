class Builders::Base
  attr_reader :build

  def initialize(build)
    @build = build
  end

  def project
    build.project
  end

  # Login to the Docker registry
  def login_to_registry(project_credential_provider)
    base_url = project_credential_provider.provider.github? ? "ghcr.io" : "registry.gitlab.com"
    docker_login_command = [ "docker", "login", base_url, "--username" ] +
                            [ project_credential_provider.username, "--password", project_credential_provider.access_token ]

    build.info("Logging into #{base_url} as #{project_credential_provider.username}", color: :yellow)
    _stdout, stderr, status = Open3.capture3(*docker_login_command)

    if status.success?
      build.success("Logged in to #{base_url} successfully.")
    else
      build.error("#{base_url} login failed with error:\n#{stderr}")
      raise "Docker login failed: #{stderr}"
    end
  end
end
