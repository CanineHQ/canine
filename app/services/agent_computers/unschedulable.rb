module AgentComputers
  # Why a computer's VM can't be placed on any node, in words a person can act on, or nil if it can. Without this a
  # full cluster only showed as a provision or start timing out, with the reason buried in the VM's conditions.
  #
  #   AgentComputers::Unschedulable.reason(vm) # => "There isn't enough free memory on the cluster ..."
  module Unschedulable
    # `vm` is the VirtualMachine, as `kubectl get vm -o json` returns it
    def self.reason(vm)
      condition = vm.dig("status", "conditions")&.find { |c| c["type"] == "PodScheduled" && c["reason"] == "Unschedulable" }
      return unless condition

      message = condition["message"].to_s
      short = if message.include?("Insufficient memory")
        "There isn't enough free memory on the cluster for this computer, which needs #{AgentComputer::MEMORY}."
      elsif message.include?("Insufficient cpu")
        "There aren't enough free CPUs on the cluster for this computer, which needs #{AgentComputer::CPU_CORES}."
      end
      return unless short # anything else (e.g. a disk still binding) can settle on its own

      "#{short} Stop another computer on it, or add a node, then try again. (Kubernetes: #{message[/\A[^.]*\./] || message})"
    end
  end
end
