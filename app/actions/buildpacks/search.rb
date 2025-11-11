class Buildpacks::Search
  extend LightService::Action
  expects :query
  promises :results

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

  # Struct for latest buildpack information
  BuildpackLatest = Struct.new(
    :id,
    :namespace,
    :name,
    :version,
    :addr,
    :yanked,
    :description,
    :homepage,
    :licenses,
    :stacks,
    :created_at,
    :updated_at,
    :version_major,
    :version_minor,
    :version_patch,
    :verified,
    keyword_init: true
  ) do
    VERIFIED_NAMESPACES = %w[io.buildpacks paketo-buildpacks heroku tanzu-buildpacks].freeze

    def self.from_hash(hash)
      new(
        id: hash["id"],
        namespace: hash["namespace"],
        name: hash["name"],
        version: hash["version"],
        addr: hash["addr"],
        yanked: hash["yanked"],
        description: hash["description"],
        homepage: hash["homepage"],
        licenses: hash["licenses"],
        stacks: hash["stacks"],
        created_at: hash["created_at"],
        updated_at: hash["updated_at"],
        version_major: hash["version_major"],
        version_minor: hash["version_minor"],
        version_patch: hash["version_patch"],
        verified: VERIFIED_NAMESPACES.include?(hash["namespace"])
      )
    end
  end

  # Struct for complete buildpack search result
  BuildpackResult = Struct.new(
    :latest,
    :versions,
    keyword_init: true
  ) do
    def self.from_hash(hash)
      new(
        latest: BuildpackLatest.from_hash(hash["latest"]),
        versions: hash["versions"]&.map { |v| BuildpackVersion.from_hash(v) } || []
      )
    end
  end

  executed do |context|
    response = HTTParty.get(
      "https://registry.buildpacks.io/api/v1/search",
      query: { matches: context.query },
      headers: {
        "Accept" => "application/json"
      }
    )

    if response.success?
      parsed_results = response.parsed_response.map { |result| BuildpackResult.from_hash(result) }
      context.results = parsed_results
    else
      context.fail_and_return!("Failed to search buildpacks: #{response.code}: #{response.message}")
    end
  end
end
