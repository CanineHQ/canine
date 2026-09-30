class AddGuestCredentialsToAgentComputers < ActiveRecord::Migration[7.2]
  def change
    # The desktop login password (lock screen, sudo) and the key Canine uses to finish setting up the VM over SSH
    add_column :agent_computers, :password, :string
    add_column :agent_computers, :ssh_private_key, :text
  end
end
