module AgentComputersHelper
  def agent_computer_layout(agent_computer, &block)
    render layout: "agent_computers/layout", locals: { agent_computer: }, &block
  end

  # Copyable kubectl/virtctl recipes for poking at an agent computer from your own machine
  def agent_computer_commands(agent_computer)
    ns = agent_computer.namespace
    vm = agent_computer.name
    launcher = "-l vm.kubevirt.io/name=#{vm}"
    api = AgentComputer::COMPUTER_SERVER_PORT
    desktop = AgentComputer::DESKTOP_PORT

    [
      { group: "Lifecycle", title: "Pause (instant resume, keeps memory)", command: "virtctl pause vm #{vm} -n #{ns}" },
      { group: "Lifecycle", title: "Resume", command: "virtctl unpause vm #{vm} -n #{ns}" },
      { group: "Lifecycle", title: "Restart", command: "virtctl restart #{vm} -n #{ns}" },
      { group: "Stats", title: "VM status", command: "kubectl get vmi #{vm} -n #{ns} -o wide" },
      { group: "Stats", title: "Live CPU / memory (includes VM overhead)", command: "kubectl top pod -n #{ns} #{launcher}" },
      { group: "Stats", title: "Disk usage (from the guest agent)", command: "kubectl get --raw /apis/subresources.kubevirt.io/v1/namespaces/#{ns}/virtualmachineinstances/#{vm}/filesystemlist" },
      { group: "Debug", title: "Serial console log (boot messages)", command: "kubectl logs -n #{ns} #{launcher} -c guest-console-log" },
      { group: "Debug", title: "Recent events", command: "kubectl get events -n #{ns} --sort-by=.lastTimestamp" },
      { group: "Debug", title: "VM resource", command: "kubectl describe vm #{vm} -n #{ns}" },
      # Port-forward to the VM's launcher pod: virtctl port-forward hangs on HTTP (client-first) connections
      { group: "Remote", title: "Desktop on localhost:#{desktop}", command: "kubectl port-forward -n #{ns} $(kubectl get pod -n #{ns} #{launcher} -o name) #{desktop}:#{desktop}" },
      { group: "Remote", title: "Computer API on localhost:#{api}", command: "kubectl port-forward -n #{ns} $(kubectl get pod -n #{ns} #{launcher} -o name) #{api}:#{api}" },
      { group: "Remote", title: "API health (after port-forward)", command: "curl -s localhost:#{api}/status" },
      { group: "Remote", title: "Save a screenshot (after port-forward)", command: %(curl -s -X POST localhost:#{api}/cmd -H 'Content-Type: application/json' -d '{"command":"screenshot"}' | jq -r .image_data | base64 -d > screenshot.png) },
      { group: "Remote", title: "Accessibility tree (after port-forward)", command: %(curl -s -X POST localhost:#{api}/cmd -H 'Content-Type: application/json' -d '{"command":"get_accessibility_tree","params":{"max_depth":6}}' | jq .tree) },
      { group: "Remote", title: "All agent commands (after port-forward)", command: "curl -s localhost:#{api}/commands | jq" }
    ]
  end

  def agent_computer_status_badge(agent_computer)
    colors = {
      "pending" => "badge-warning",
      "provisioning" => "badge-info",
      "running" => "badge-success",
      "stopped" => "badge-neutral",
      "failed" => "badge-error",
      "destroying" => "badge-warning"
    }
    badge_class = colors[agent_computer.status] || "badge-neutral"
    tag.span(agent_computer.status.titleize, class: "badge #{badge_class} badge-sm")
  end
end
