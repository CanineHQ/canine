# frozen_string_literal: true

module Tools
  module Concerns
    # Shared by the computer_* tools: find a running agent computer the user can use, and turn the computer-use
    # server's replies into MCP responses (screenshots as images, everything else as JSON text).
    module AgentComputerAccess
      extend ActiveSupport::Concern

      # Every computer tool's description ends with this, so Claude reaches for pixels last: they're the slowest and
      # least reliable way to act, and the only one that depends on reading coordinates off an image
      PREFERENCE = <<~TEXT.squish
        Prefer, in this order: computer_run (shell commands, output as text), computer_terminal (interactive terminal
        programs, read and typed as text) and computer_windows (open apps and URLs, focus/move/close windows, switch
        workspaces); then computer_accessibility (find and press buttons, links and fields by name); then keyboard
        shortcuts (computer_action key). Click at screenshot coordinates only for what none of those can reach.
      TEXT

      class_methods do
        def with_agent_computer(agent_computer_id, server_context:)
          with_account_users(server_context: server_context) do |user, account_users|
            computer = find_agent_computer(agent_computer_id, account_users)
            next error_response("Agent computer not found or you don't have access to it") unless computer
            next error_response("Agent computer '#{computer.name}' is #{computer.status}; start it first") unless computer.running?

            # The agent loop passes its own client, which keeps one tunnel open for a whole turn
            shared = server_context[:computer_use]
            yield(shared&.computer == computer ? shared : AgentComputers::ComputerUse.new(computer, K8::Connection.new(computer.cluster, user)))
          end
        rescue AgentComputers::ComputerUse::Error => e
          error_response(e.message)
        end

        def result_response(result)
          content = []
          if result["image"]
            content << { type: "image", data: result.delete("image"), mimeType: "image/#{result.delete("format") || "png"}" }
          end
          content << { type: "text", text: result.to_json } if result.present? || content.empty?
          MCP::Tool::Response.new(content)
        end

        def error_response(message)
          MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
        end
      end
    end
  end
end
