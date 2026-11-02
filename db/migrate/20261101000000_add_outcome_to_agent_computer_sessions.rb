class AddOutcomeToAgentComputerSessions < ActiveRecord::Migration[7.2]
  def change
    # Whether the task got done, as the model said when it finished (done, partly_done, blocked); nil for runs that
    # ended any other way
    add_column :agent_computer_sessions, :outcome, :integer
  end
end
