class DockerCli
  class AuthenticationError < StandardError; end

  def self.with_registry_auth(registry_url:, username:, password:, &block)
    normalized_registry = normalize_registry_url(registry_url)

    # Login to registry
    login_success = login(normalized_registry, username, password)
    unless login_success
      raise AuthenticationError, "Failed to authenticate with registry: #{normalized_registry}"
    end

    # Execute the block
    begin
      yield
    ensure
      # Always logout, even if block raises an exception
      logout(normalized_registry)
    end
  end

  private

  def self.login(registry, username, password)
    docker_login_command = [
      "docker", "login", registry,
      "--username", username,
      "--password-stdin"
    ]

    stdout, stderr, status = Open3.capture3(*docker_login_command, stdin_data: password)

    if status.success?
      Rails.logger.info("Successfully logged in to #{registry}")
      true
    else
      Rails.logger.error("Docker login failed for #{registry}: #{stderr}")
      false
    end
  rescue StandardError => e
    Rails.logger.error("Docker login error: #{e.message}")
    false
  end

  def self.logout(registry)
    stdout, stderr, status = Open3.capture3("docker", "logout", registry)

    if status.success?
      Rails.logger.info("Successfully logged out from #{registry}")
    else
      Rails.logger.warn("Docker logout failed for #{registry}: #{stderr}")
    end
  rescue StandardError => e
    Rails.logger.warn("Docker logout error: #{e.message}")
  end

  def self.normalize_registry_url(url)
    return "docker.io" if url.blank?

    # Remove protocol if present
    url = url.sub(/^https?:\/\//, '')
    # Remove trailing slashes and paths
    url = url.sub(/\/.*$/, '')
    # Handle Docker Hub special cases
    if url.include?('docker.io') || url.include?('index.docker.io')
      'docker.io'
    else
      url
    end
  end
end
