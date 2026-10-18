# Agent computer pages 404 for accounts without the agent_computers flag (AgentComputer.enabled_for?)
module AgentComputers::FeatureGate
  extend ActiveSupport::Concern

  included do
    before_action :require_agent_computers_feature
  end

  private

  def require_agent_computers_feature
    raise ActionController::RoutingError, "Not Found" unless AgentComputer.enabled_for?(current_account)
  end
end
