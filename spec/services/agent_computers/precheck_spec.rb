require "rails_helper"

RSpec.describe AgentComputers::Precheck do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account, name: "home"), account_user:, memory: "8Gi") }
  let(:deployed) { { "items" => [ { "status" => { "phase" => "Deployed" } } ] } }
  let(:node) do
    { "metadata" => { "name" => "node-a" }, "spec" => {},
      "status" => { "conditions" => [ { "type" => "Ready", "status" => "True" } ],
                    "allocatable" => { "memory" => "16Gi", "devices.kubevirt.io/kvm" => "1k" } } }
  end
  let(:pods) { [ { "spec" => { "nodeName" => "node-a", "containers" => [ { "resources" => { "requests" => { "memory" => "4Gi" } } } ] } } ] }
  let(:storage) { [ { "metadata" => { "name" => "local-path", "annotations" => { "storageclass.kubernetes.io/is-default-class" => "true" } } } ] }

  def kubectl(nodes: [ node ], pods: self.pods, storage: self.storage, kubevirt: deployed)
    ->(args) do
      case args[1]
      when "kubevirt", "cdi" then kubevirt.to_json
      when "nodes" then { "items" => nodes }.to_json
      when "pods" then { "items" => pods }.to_json
      when "storageclass" then { "items" => storage }.to_json
      end
    end
  end

  it "passes a cluster that can run the computer, and says why each check failed when it can't" do
    lines = []
    described_class.new(computer, kubectl).run! { |line| lines << line }
    expect(lines).to eq([ "KubeVirt and CDI are running", "1 node can run VMs with KVM",
                          "node-a has 12Gi free for this computer's 8Gi", "Disks go on the default StorageClass, local-path" ])

    expect { described_class.new(computer, kubectl(kubevirt: { "items" => [] })).run! }
      .to raise_error(described_class::Failed, /KubeVirt and CDI aren't installed on the cluster “home”/)
    no_kvm = node.deep_merge("status" => { "allocatable" => { "devices.kubevirt.io/kvm" => "0" } })
    expect { described_class.new(computer, kubectl(nodes: [ no_kvm ])).run! }
      .to raise_error(described_class::Failed, %r{doesn't see KVM \(/dev/kvm\).*VT-x}m)
    full = [ { "spec" => { "nodeName" => "node-a", "containers" => [ { "resources" => { "requests" => { "memory" => "12Gi" } } } ] } } ]
    expect { described_class.new(computer, kubectl(pods: full)).run! }
      .to raise_error(described_class::Failed, /needs 8Gi .* has free is 4Gi \(node-a\)/)
    expect { described_class.new(computer, kubectl(storage: [])).run! }
      .to raise_error(described_class::Failed, /The cluster “home” has no default StorageClass/)
  end

  it "fails a provision with the precheck's words, without raising" do
    allow(K8::Connection).to receive(:new).and_return(instance_double(K8::Connection))
    allow(K8::Kubectl).to receive(:new).and_return(kubectl(storage: []))
    AgentComputers::ProvisionJob.perform_now(computer)
    expect(computer.reload).to be_failed
    expect(computer.failure).to start_with("The cluster “home” has no default StorageClass")
  end
end
