require 'rails_helper'

RSpec.describe Clusters::SyncPackages do
  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account: account) }
  let(:user) { create(:user) }
  let(:connection) { instance_double(K8::Connection) }
  let(:kubectl) { instance_double(K8::Kubectl) }

  before do
    allow(K8::Connection).to receive(:new).with(cluster, user).and_return(connection)
    allow(K8::Kubectl).to receive(:new).with(connection).and_return(kubectl)
    allow(cluster).to receive(:info)
    allow(cluster).to receive(:success)
  end

  def stub_installed(package_name, detected:)
    installer = instance_double(ClusterPackage::Installer::Base)
    allow(installer).to receive(:installed?).with(kubectl).and_return(detected)
    allow_any_instance_of(ClusterPackage).to receive(:installer).and_wrap_original do |original, *args|
      pkg = original.receiver
      pkg.name == package_name ? installer : original.call(*args)
    end
    installer
  end

  def stub_all_not_installed
    allow_any_instance_of(ClusterPackage::Installer::Base).to receive(:installed?).with(kubectl).and_return(false)
  end

  describe "does not create packages that are not detected" do
    it "does not create cluster_package records when nothing is found on the cluster" do
      stub_all_not_installed
      expect {
        described_class.execute(cluster: cluster, user: user)
      }.not_to change { cluster.cluster_packages.count }
    end
  end

  describe "creates packages that are detected externally" do
    it "creates a cluster_package record when detected on the cluster" do
      stub_all_not_installed
      stub_installed("traefik-ingress", detected: true)

      expect {
        described_class.execute(cluster: cluster, user: user)
      }.to change { cluster.cluster_packages.where(name: "traefik-ingress").count }.from(0).to(1)

      package = cluster.cluster_packages.find_by(name: "traefik-ingress")
      expect(package).to be_installed
      expect(package.installed_at).to be_present
    end
  end

  describe "updates existing packages" do
    it "marks a pending package as installed when detected" do
      package = create(:cluster_package, cluster: cluster, name: "traefik-ingress", status: :pending)
      stub_all_not_installed
      stub_installed("traefik-ingress", detected: true)

      described_class.execute(cluster: cluster, user: user)

      expect(package.reload).to be_installed
    end

    it "marks an installed package as uninstalled when not detected" do
      package = create(:cluster_package, cluster: cluster, name: "traefik-ingress", status: :installed)
      stub_all_not_installed

      described_class.execute(cluster: cluster, user: user)

      expect(package.reload).to be_uninstalled
    end

    it "does not touch an already-installed package that is still detected" do
      package = create(:cluster_package, cluster: cluster, name: "traefik-ingress", status: :installed, installed_at: 1.day.ago)
      stub_all_not_installed
      stub_installed("traefik-ingress", detected: true)

      expect {
        described_class.execute(cluster: cluster, user: user)
      }.not_to change { package.reload.updated_at }
    end
  end
end
