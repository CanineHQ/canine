# What the agent pages share: they're behind the `agent_computers` Flipper flag, per account (AgentComputer.enabled_for?),
# and don't exist (404) without it. Pages on one computer (its tasks, runs and feed) also find that computer.
class AgentComputers::BaseController < ApplicationController
  include AgentComputers::FeatureGate
  before_action :set_agent_computer

  private

  def set_agent_computer
    @agent_computer = current_account.agent_computers.find(params[:agent_computer_id])
  end
end
