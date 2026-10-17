# What an agent computer's own pages (its tasks, runs and feed) share: the feature flag, and the computer they're on
class AgentComputers::BaseController < ApplicationController
  include AgentTasksFeature

  before_action :set_agent_computer

  private

  def set_agent_computer
    @agent_computer = current_account.agent_computers.find(params[:agent_computer_id])
  end
end
