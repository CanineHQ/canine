class AddComputerUseTokenToAgentComputers < ActiveRecord::Migration[7.2]
  class AgentComputer < ActiveRecord::Base; end

  def up
    # The bearer token Canine sends the computer-use server in the VM (resources/agent_computer/computer_use/auth.py)
    add_column :agent_computers, :computer_use_token, :string
    AgentComputer.reset_column_information
    AgentComputer.find_each { |computer| computer.update_columns(computer_use_token: SecureRandom.urlsafe_base64(32)) }
  end

  def down
    remove_column :agent_computers, :computer_use_token
  end
end
