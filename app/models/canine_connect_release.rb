# The Canine Connect macOS app (canine-connect/), published to GitHub releases by
# .github/workflows/canine-connect.yml. VERSION must match CFBundleShortVersionString in
# canine-connect/Resources/Info.plist.
class CanineConnectRelease
  VERSION = "0.1.0".freeze
  REPOSITORY = "CanineHQ/canine".freeze
  ARCHITECTURES = {
    "arm64" => "Apple Silicon",
    "x86_64" => "Intel"
  }.freeze

  def self.download_url(arch)
    raise ArgumentError, "Unknown architecture: #{arch}" unless ARCHITECTURES.key?(arch)

    "https://github.com/#{REPOSITORY}/releases/download/canine-connect-v#{VERSION}/CanineConnect-macos-#{arch}.zip"
  end

  # Installs from the terminal. curl doesn't quarantine what it downloads, so Gatekeeper doesn't block the
  # app the way it does a browser download of an app that isn't notarized.
  def self.install_command(arch = "arm64")
    [
      "curl -fsSL #{download_url(arch)} -o /tmp/CanineConnect.zip",
      "ditto -x -k /tmp/CanineConnect.zip ~/Applications",
      "open ~/Applications/\"Canine Connect.app\""
    ].join(" && ")
  end

  # Canine Connect needs the cluster's Traffic Manager, installed by the telepresence cluster package
  def self.ready_on?(cluster)
    cluster.cluster_packages.any? { |package| package.name == "telepresence" && package.installed? }
  end

  def self.telepresence_version
    ClusterPackage.definitions.find { |d| d["name"] == "telepresence" }&.dig("chart_version")
  end
end
