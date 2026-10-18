# == Schema Information
#
# Table name: agent_computer_session_messages
#
#  id           :bigint           not null, primary key
#  content      :jsonb
#  position     :integer          not null
#  role         :string           not null
#  tool_calls   :jsonb
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  session_id   :bigint           not null
#  tool_call_id :string
#
# Indexes
#
#  idx_on_session_id_position_8c06d1dd5f                (session_id,position) UNIQUE
#  index_agent_computer_session_messages_on_session_id  (session_id)
#
# Foreign Keys
#
#  fk_rails_...  (session_id => agent_computer_sessions.id)
#
class AgentComputer::Session::Message < ApplicationRecord
  belongs_to :session

  validates :role, inclusion: { in: %w[system user assistant tool] }

  # The message as the OpenAI-compatible chat API takes it
  def to_api
    { role:, content:, tool_calls:, tool_call_id: }.compact
  end
end
