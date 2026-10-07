# == Schema Information
#
# Table name: agent_session_activities
#
#  id                     :bigint           not null, primary key
#  description            :text
#  finished_at            :datetime
#  first_message_position :integer
#  intent                 :string
#  outcome                :text
#  position               :integer          not null
#  started_at             :datetime
#  tidied_at              :datetime
#  title                  :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  agent_session_id       :bigint           not null
#
# Indexes
#
#  index_agent_session_activities_on_agent_session_id  (agent_session_id)
#
# Foreign Keys
#
#  fk_rails_...  (agent_session_id => agent_sessions.id)
#
class AgentSessionActivity < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :session, class_name: "AgentSession", foreign_key: :agent_session_id
  has_many :actions, -> { order(:created_at) }, class_name: "AgentSessionAction", foreign_key: :agent_session_activity_id,
                                                dependent: :destroy

  # New activities slide in; an updated one only types out the new part of its description
  after_create_commit lambda {
    broadcast_append_to session, target: dom_id(session, :activities), partial: "agent_sessions/activity", locals: { activity: self, animate: true }
  }
  after_update_commit lambda {
    broadcast_replace_to session, target: dom_id(self), partial: "agent_sessions/activity",
                                  locals: { activity: self, reveal_from: description_previously_changed? ? description_previously_was.to_s.length : nil }
  }

  def self.same_intent?(a, b)
    normalize(a) == normalize(b)
  end

  def self.normalize(intent)
    intent.to_s.downcase.gsub(/[^a-z0-9 ]/, " ").squish
  end

  def current?
    finished_at.nil? && session.active?
  end

  # Ended (or ending) badly: a failed or blocked action that nothing later in the activity got past
  def troubled?
    last_doing = actions.reject(&:look_only?).last
    last_doing&.failed? || last_doing&.blocked?
  end

  def duration
    return unless started_at

    (finished_at || Time.current) - started_at
  end

  # Close it; it's tidied with the next batch
  def finish!
    return if finished_at

    update!(finished_at: Time.current)
    AgentLoop::Tidy.enqueue(session)
  end
end
