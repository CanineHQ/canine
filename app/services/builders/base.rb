class Builders::Base
  attr_reader :build

  def initialize(build)
    @build = build
  end

  def project
    build.project
  end

  # Login to the Docker registry
  def login_to_registry
    provider = project.build_provider
    base_url = provider.registry_base_url
    docker_login_command = [ "docker", "login", base_url, "--username" ] +
                            [ provider.username, "--password", provider.access_token ]

    build.info("Logging into #{base_url} as #{provider.username}", color: :yellow)
    _stdout, stderr, status = Open3.capture3(*docker_login_command)

    if status.success?
      build.success("Logged in to #{base_url} successfully.")
    else
      build.error("#{base_url} login failed with error:\n#{stderr}")
      raise "Docker login failed: #{stderr}"
    end
  end

  def setup
  end

  def cleanup
  end
end
