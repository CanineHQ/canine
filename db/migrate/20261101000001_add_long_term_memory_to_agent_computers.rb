class AddLongTermMemoryToAgentComputers < ActiveRecord::Migration[7.2]
  def change
    # What the agent has learned on this computer, across all its runs: one note per line ("- …"), added with the
    # remember tool and shown to every run (AgentLoop::SystemPrompt). Not `memory`, which is the VM's RAM.
    add_column :agent_computers, :long_term_memory, :text
  end
end
