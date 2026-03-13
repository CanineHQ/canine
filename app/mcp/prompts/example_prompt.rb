class Prompts::ExamplePrompt < MCP::Prompt
  prompt_name "my_prompt"  # Optional - defaults to underscored class name
  title "My Prompt"
  description "This prompt performs specific functionality..."
  arguments [
    MCP::Prompt::Argument.new(
      name: "message",
      title: "Message Title",
      description: "Input message",
      required: true
    )
  ]
  meta({ version: "1.0", category: "example" })

  class << self
    def template(args, server_context:)
      MCP::Prompt::Result.new(
        description: "Response description",
        messages: [
          MCP::Prompt::Message.new(
            role: "user",
            content: MCP::Content::Text.new("User message")
          ),
          MCP::Prompt::Message.new(
            role: "assistant",
            content: MCP::Content::Text.new(args["message"])
          )
        ]
      )
    end
  end
end
