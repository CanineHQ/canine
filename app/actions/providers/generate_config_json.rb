class Providers::GenerateConfigJson
  extend LightService::Action
  expects :provider
  promises :docker_config_json

  executed do |context|
    registry = context.provider.registry_base_url
    context.docker_config_json = create_docker_json_structure(
      context.provider.username,
      context.provider.access_token,
      registry,
    )
  end

  def self.create_docker_json_structure(username, password, registry)
    # First base64 encoding
    auth_value = Base64.strict_encode64("#{username}:#{password}")

    # Create the JSON structure
    docker_config = {
      "auths" => {
        registry => {
          "auth" => auth_value
        }
      }
    }

    # Second base64 encoding of the entire JSON
    Base64.strict_encode64(JSON.generate(docker_config))
  end
end
