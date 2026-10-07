# frozen_string_literal: true

module Tools
  class ComputerScreenshot < MCP::Tool
    include Tools::Concerns::Authentication
    include Tools::Concerns::AgentComputerAccess

    description <<~TEXT.squish
      Take a screenshot of an agent computer's desktop, to see what's there or check what an action did. Coordinates
      in the image are what computer_action takes. #{Tools::Concerns::AgentComputerAccess::PREFERENCE}
    TEXT

    input_schema(
      properties: {
        agent_computer_id: { type: "integer", description: "The agent computer (from list_agent_computers)" }
      },
      required: [ "agent_computer_id" ]
    )

    annotations(read_only_hint: true)

    def self.call(agent_computer_id:, server_context:)
      with_agent_computer(agent_computer_id, server_context:) do |computer_use|
        result_response(computer_use.perform(action: "screenshot"))
      end
    end
  end
end
