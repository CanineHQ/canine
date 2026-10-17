# What the agent pages share: agent tasks and sessions (the scheduled agent loop) are behind the `agent_tasks` Flipper
# flag, per account. Without it their pages don't exist (404), and the scheduler skips the account's tasks
# (AgentTasks::ScheduleJob). Pages on one computer (its tasks, runs and feed) also find that computer.
class AgentComputers::BaseController < ApplicationController
  before_action :require_agent_tasks_feature
  before_action :set_agent_computer

  private

  def require_agent_tasks_feature
    raise ActionController::RoutingError, "Not Found" unless AgentComputer::Task.enabled_for?(current_account)
  end

  def set_agent_computer
    @agent_computer = current_account.agent_computers.find(params[:agent_computer_id])
  end
end
