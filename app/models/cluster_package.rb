# == Schema Information
#
# Table name: cluster_packages
#
#  id           :bigint           not null, primary key
#  config       :jsonb
#  installed_at :datetime
#  name         :string           not null
#  status       :integer          default("pending"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cluster_id   :bigint           not null
#
# Indexes
#
#  index_cluster_packages_on_cluster_id           (cluster_id)
#  index_cluster_packages_on_cluster_id_and_name  (cluster_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#
class ClusterPackage < ApplicationRecord
  include Loggable

  belongs_to :cluster

  enum :status, {
    pending: 0,
    installing: 1,
    installed: 2,
    failed: 3,
    uninstalling: 4,
    uninstalled: 5
  }

  validates :name, presence: true, uniqueness: { scope: :cluster_id }

  after_update_commit :broadcast_package

  DEFINITIONS = YAML.load_file(Rails.root.join("resources", "helm", "system_packages.yml"))["packages"]

  INSTALLER_REGISTRY = {
    "nginx-ingress" => "ClusterPackage::Installer::NginxIngress",
    "cert-manager" => "ClusterPackage::Installer::CertManager",
    "metrics-server" => "ClusterPackage::Installer::MetricsServer",
    "telepresence" => "ClusterPackage::Installer::Telepresence",
    "cloudflared" => "ClusterPackage::Installer::Cloudflared",
    "error-tracking" => "ClusterPackage::Installer::ErrorTracking"
  }.freeze

  def definition
    DEFINITIONS.find { |d| d["name"] == name }
  end

  def installer
    class_name = INSTALLER_REGISTRY.fetch(name) { raise "No installer registered for package: #{name}" }
    class_name.constantize.new(self)
  end

  def configurable?
    definition&.dig("template").present?
  end

  def self.definitions
    DEFINITIONS
  end

  def self.default_package_names
    DEFINITIONS.select { |d| d["default"] }.map { |d| d["name"] }
  end

  def self.permitted_config_keys(package_name)
    defn = DEFINITIONS.find { |d| d["name"] == package_name }
    defn&.dig("template")&.map { |field| field["key"] } || []
  end

  def broadcast_package
    broadcast_replace_later_to [ cluster, :cluster_packages ],
      target: "cluster_#{cluster_id}_package_#{name}",
      partial: "clusters/cluster_packages/package_row",
      locals: { cluster: cluster, definition: definition, package: self }
  end
end
