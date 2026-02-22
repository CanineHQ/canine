require 'rails_helper'

RSpec.describe K8::Kubeconfig do
  describe ".remap_localhost" do
    it "remaps localhost and 127.0.0.1 to the given host" do
      expect(described_class.remap_localhost("https://localhost:6443", "host.docker.internal")).to eq("https://host.docker.internal:6443")
      expect(described_class.remap_localhost("https://127.0.0.1:6443", "host.docker.internal")).to eq("https://host.docker.internal:6443")
    end

    it "doesn't remap non-localhost addresses" do
      expect(described_class.remap_localhost("https://example.com:6443", "host.docker.internal")).to eq("https://example.com:6443")
    end
  end
end
