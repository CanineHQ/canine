# Agent tasks and sessions (the scheduled agent loop) are behind the `agent_tasks` Flipper flag, per account. Without
# it, their pages don't exist (404) and the scheduler skips the account's tasks (AgentTasks::ScheduleJob).
module AgentTasksFeature
  extend ActiveSupport::Concern

  included do
    before_action :require_agent_tasks_feature
  end

  private

  def require_agent_tasks_feature
    raise ActionController::RoutingError, "Not Found" unless AgentTask.enabled_for?(current_account)
  end
end
