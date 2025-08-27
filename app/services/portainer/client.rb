class Portainer::Client
  include HTTParty
  def initialize(portainer_url, portainer_token)
    @portainer_url = portainer_url
    @portainer_token = portainer_token
  end

  def registries
    response = self.class.get(
      "#{@portainer_url}/api/registries",
      headers: {
        "Authorization" => "Bearer #{@portainer_token}"
      }
    )

    raise "Failed to fetch registries from Portainer" unless response.success?

    registries_data = JSON.parse(response.body)
    registries_data.map do |registry_data|
      Portainer::Data::Registry.new(
        id: registry_data["Id"],
        name: registry_data["Name"],
        url: registry_data["URL"],
        username: registry_data["Username"],
        password: registry_data["Password"],
        authentication: registry_data["Authentication"]
      )
    end
  end

  def endpoints
    response = self.class.get(
      "#{@portainer_url}/api/endpoints",
      headers: {
        "Authorization" => "Bearer #{@portainer_token}"
      }
    )

    raise "Failed to fetch endpoints from Portainer" unless response.success?

    endpoints_data = JSON.parse(response.body)
    endpoints_data.map do |endpoint_data|
      Portainer::Data::Endpoint.new(
        id: endpoint_data["Id"],
        name: endpoint_data["Name"],
        url: endpoint_data["URL"]
      )
    end
  end

  def get_registry_secret(project, registry_id)
    # curl 'https://demo.portainer.io/api/endpoints/4/registries/4' \
    # -X PUT \
    # --data-raw '{"namespaces":["ingress","sk-ns"]}'

    response = self.class.put(
      "#{@portainer_url}/api/endpoints/#{endpoint_id}/registries/#{registry_id}",
      headers: {
        "Authorization" => "Bearer #{@portainer_token}"
      },
      body: { namespaces: [project.name] }
    )

    raise "Failed to put registry secret to cluster" unless response.success?

    JSON.parse(response.body)
  end
end
