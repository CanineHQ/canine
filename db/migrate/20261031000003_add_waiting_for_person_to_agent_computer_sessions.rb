class AddWaitingForPersonToAgentComputerSessions < ActiveRecord::Migration[7.2]
  def change
    # A run paused on a question for the person (status waiting_for_person): since when, and how long it has waited in
    # all, which doesn't count against its time limit
    add_column :agent_computer_sessions, :waiting_since, :datetime
    add_column :agent_computer_sessions, :waited_seconds, :integer, default: 0, null: false
    # The browser tab a browse left open when it stopped to ask the person (a code form); the next browse carries on in it
    add_column :agent_computer_sessions, :kept_tab, :string
  end
end
