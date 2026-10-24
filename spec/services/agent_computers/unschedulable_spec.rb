require "rails_helper"

RSpec.describe AgentComputers::Unschedulable do
  def vm(message)
    { "spec" => { "template" => { "spec" => { "domain" => { "memory" => { "guest" => "16Gi" } } } } },
      "status" => { "conditions" => [ { "type" => "PodScheduled", "status" => "False", "reason" => "Unschedulable", "message" => message } ] } }
  end

  it "explains a full cluster, and leaves anything that can settle on its own alone" do
    reason = described_class.reason(vm("0/1 nodes are available: 1 Insufficient memory. preemption: 0/1 nodes are available"))
    expect(reason).to start_with("There isn't enough free memory on the cluster for this computer, which needs 16Gi.")
    expect(reason).to end_with("(Kubernetes: 0/1 nodes are available: 1 Insufficient memory.)")

    expect(described_class.reason(vm("0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims"))).to be_nil
    expect(described_class.reason({ "status" => { "printableStatus" => "Running" } })).to be_nil
  end

  it "is saved on the computer when it fails, and cleared when it's tried again" do
    account_user = create(:account_user)
    computer = AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:)
    computer.fail!(RuntimeError.new("No room"))
    expect(computer.reload).to have_attributes(status: "failed", failure: "No room")

    computer.provisioning!
    expect(computer.reload.failure).to be_nil
  end
end
