module AgentSandboxesHelper
  def agent_sandbox_layout(agent_sandbox, &block)
    render layout: "agent_sandboxes/layout", locals: { agent_sandbox: }, &block
  end

  def agent_sandbox_status_badge(agent_sandbox)
    colors = {
      "pending" => "badge-warning",
      "provisioning" => "badge-info",
      "running" => "badge-success",
      "stopped" => "badge-neutral",
      "failed" => "badge-error",
      "destroying" => "badge-warning"
    }
    badge_class = colors[agent_sandbox.status] || "badge-neutral"
    tag.span(agent_sandbox.status.titleize, class: "badge #{badge_class} badge-sm")
  end
end
