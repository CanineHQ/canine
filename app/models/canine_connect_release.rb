# The Canine Connect macOS app, which lives in CanineHQ/connect. Its release workflow attaches
# CanineConnect-macos-<arch>.zip to each release; these links always take the latest one.
class CanineConnectRelease
  REPOSITORY = "CanineHQ/connect".freeze
  ARCHITECTURES = {
    "arm64" => "Apple Silicon",
    "x86_64" => "Intel"
  }.freeze

  def self.download_url(arch)
    raise ArgumentError, "Unknown architecture: #{arch}" unless ARCHITECTURES.key?(arch)

    "https://github.com/#{REPOSITORY}/releases/latest/download/CanineConnect-macos-#{arch}.zip"
  end

  # Canine Connect needs the cluster's Traffic Manager, installed by the telepresence cluster package
  def self.ready_on?(cluster)
    cluster.cluster_packages.any? { |package| package.name == "telepresence" && package.installed? }
  end

  # Opens the installed app with this Canine's address in its sign-in form. Canine can be self-hosted, so the
  # app cannot know where to sign in until it is told.
  def self.open_url(canine_url)
    "canine-connect://connect?#{{ url: canine_url }.to_query}"
  end

  def self.repository_url
    "https://github.com/#{REPOSITORY}"
  end

  def self.telepresence_version
    ClusterPackage.definitions.find { |d| d["name"] == "telepresence" }&.dig("chart_version")
  end
end
