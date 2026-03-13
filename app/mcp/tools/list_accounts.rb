# frozen_string_literal: true

module Tools
  class ListAccounts < MCP::Tool
    title "List accounts"
    description "List all accounts accessible to the current user and their resources (clusters, projects, add-ons). IMPORTANT: Call this tool first to discover available accounts before using other tools that require an account_id parameter."
    idempotent_hint true
    read_only_hint true

    input_schema(
      properties: {},
      required: []
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(server_context:)
      user = User.find(server_context[:user_id])

      accounts = user.accounts.includes(:clusters, clusters: [ :projects, :add_ons ])

      account_list = accounts.map do |account|
        Api::Accounts::ShowViewModel.new(account).as_json
      end

      MCP::Tool::Response.new([ {
        type: "text",
        text: account_list.to_json
      } ])
    end
  end
end
