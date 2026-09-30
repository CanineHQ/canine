class AddDesktopToAgentComputers < ActiveRecord::Migration[7.2]
  def change
    # How the Desktop tab shows the computer: "selkies" (stream from inside the guest) or "vnc" (the VM's own screen via KubeVirt)
    add_column :agent_computers, :desktop, :string, null: false, default: "selkies"
  end
end
