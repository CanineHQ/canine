# == Schema Information
#
# Table name: agent_session_messages
#
#  id               :bigint           not null, primary key
#  content          :jsonb
#  position         :integer          not null
#  role             :string           not null
#  tool_calls       :jsonb
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  agent_session_id :bigint           not null
#  tool_call_id     :string
#
# Indexes
#
#  index_agent_session_messages_on_agent_session_id               (agent_session_id)
#  index_agent_session_messages_on_agent_session_id_and_position  (agent_session_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agent_session_id => agent_sessions.id)
#
class AgentSessionMessage < ApplicationRecord
  belongs_to :session, class_name: "AgentSession", foreign_key: :agent_session_id

  validates :role, inclusion: { in: %w[system user assistant tool] }

  # The message as the OpenAI-compatible chat API takes it
  def to_api
    { role:, content:, tool_calls:, tool_call_id: }.compact
  end
end
