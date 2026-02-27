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
require 'rails_helper'

RSpec.describe ClusterPackage, type: :model do
  let(:cluster_package) { build(:cluster_package) }

  it "is valid with factory defaults and can look up its definition" do
    expect(cluster_package).to be_valid
    expect(cluster_package.definition).to be_present
    expect(cluster_package.definition["display_name"]).to eq("Nginx Ingress")
  end

  it "returns default package names from YAML config" do
    defaults = ClusterPackage.default_package_names
    expect(defaults).to include("nginx-ingress", "cert-manager", "metrics-server", "telepresence")
    expect(defaults).not_to include("cloudflared")
  end

  it "identifies configurable packages" do
    configurable_pkg = build(:cluster_package, name: "cloudflared")
    expect(configurable_pkg.configurable?).to be true

    non_configurable_pkg = build(:cluster_package, name: "nginx-ingress")
    expect(non_configurable_pkg.configurable?).to be false
  end

  it "resolves the correct installer class for each package" do
    expect(build(:cluster_package, name: "nginx-ingress").installer).to be_a(ClusterPackage::Installer::NginxIngress)
    expect(build(:cluster_package, name: "cert-manager").installer).to be_a(ClusterPackage::Installer::CertManager)
    expect(build(:cluster_package, name: "metrics-server").installer).to be_a(ClusterPackage::Installer::MetricsServer)
    expect(build(:cluster_package, name: "telepresence").installer).to be_a(ClusterPackage::Installer::Telepresence)
    expect(build(:cluster_package, name: "cloudflared").installer).to be_a(ClusterPackage::Installer::Cloudflared)
  end

  it "falls back to Base installer for unknown packages" do
    pkg = build(:cluster_package, name: "unknown-package")
    expect(pkg.installer).to be_a(ClusterPackage::Installer::Base)
  end
end
