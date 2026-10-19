require 'rails_helper'

RSpec.describe ClusterPackage::Installer::Registry do
  let(:package) { create(:cluster_package, name: ClusterRegistry::PACKAGE_NAME) }
  let(:kubectl) { double(apply_yaml: nil, call: nil) }

  it 'generates a password once, keeps it across reinstalls and puts its hash in the manifest' do
    described_class.new(package).install!(kubectl)
    password = package.reload.config["password"]
    expect(password).to be_present

    described_class.new(package).install!(kubectl)
    expect(package.reload.config["password"]).to eq(password)

    expect(kubectl).to have_received(:apply_yaml).twice do |yaml|
      htpasswd = YAML.load_stream(yaml).find { |doc| doc["kind"] == "Secret" }.dig("stringData", "htpasswd")
      expect(BCrypt::Password.new(htpasswd.delete_prefix("canine:"))).to eq(password)
    end
  end
end
