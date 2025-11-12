class Buildpacks::Details
  extend LightService::Action
  expects :namespace, :name
  promises :result

  # Struct for individual buildpack versions
  BuildpackVersion = Struct.new(
    :version,
    :link,
    keyword_init: true
  ) do
    def self.from_hash(hash)
      new(
        version: hash["version"],
        link: hash["_link"]
      )
    end
  end

  # Struct for latest buildpack information (details endpoint has fewer fields)
  BuildpackLatestDetails = Struct.new(
    :version,
    :namespace,
    :name,
    :description,
    :homepage,
    :licenses,
    :stacks,
    :id,
    :verified,
    keyword_init: true
  ) do
    VERIFIED_NAMESPACES = %w[io.buildpacks paketo-buildpacks heroku tanzu-buildpacks].freeze

    def self.from_hash(hash)
      new(
        version: hash["version"],
        namespace: hash["namespace"],
        name: hash["name"],
        description: hash["description"],
        homepage: hash["homepage"],
        licenses: hash["licenses"],
        stacks: hash["stacks"],
        id: hash["id"],
        verified: VERIFIED_NAMESPACES.include?(hash["namespace"])
      )
    end
  end

  # Struct for buildpack details result
  BuildpackDetailsResult = Struct.new(
    :latest,
    :versions,
    keyword_init: true
  ) do
    def self.from_hash(hash)
      new(
        latest: BuildpackLatestDetails.from_hash(hash["latest"]),
        versions: hash["versions"]&.map { |v| BuildpackVersion.from_hash(v) } || []
      )
    end
  end

  executed do |context|
    response = HTTParty.get(
      "https://registry.buildpacks.io/api/v1/buildpacks/#{context.namespace}/#{context.name}",
      headers: {
        "Accept" => "application/json"
      }
    )

    if response.success?
      context.result = BuildpackDetailsResult.from_hash(response.parsed_response)
    else
      context.fail_and_return!("Failed to fetch buildpack details: #{response.code}: #{response.message}")
    end
  end
end
