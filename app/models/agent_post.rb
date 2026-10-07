# == Schema Information
#
# Table name: agent_posts
#
#  id                        :bigint           not null, primary key
#  kind                      :string           not null
#  position                  :integer          default(0), not null
#  posted_at                 :datetime         not null
#  text                      :text             not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  agent_computer_id         :bigint           not null
#  agent_session_action_id   :bigint
#  agent_session_activity_id :bigint
#  agent_session_id          :bigint           not null
#
# Indexes
#
#  index_agent_posts_on_agent_computer_id                (agent_computer_id)
#  index_agent_posts_on_agent_computer_id_and_posted_at  (agent_computer_id,posted_at)
#  index_agent_posts_on_agent_session_action_id          (agent_session_action_id)
#  index_agent_posts_on_agent_session_activity_id        (agent_session_activity_id)
#  index_agent_posts_on_agent_session_id                 (agent_session_id)
#
# Foreign Keys
#
#  fk_rails_...  (agent_computer_id => agent_computers.id)
#  fk_rails_...  (agent_session_action_id => agent_session_actions.id) ON DELETE => nullify
#  fk_rails_...  (agent_session_activity_id => agent_session_activities.id) ON DELETE => nullify
#  fk_rails_...  (agent_session_id => agent_sessions.id)
#
class AgentPost < ApplicationRecord
  KINDS = %w[done found needs_you problem].freeze

  belongs_to :agent_computer
  belongs_to :session, class_name: "AgentSession", foreign_key: :agent_session_id
  belongs_to :activity, class_name: "AgentSessionActivity", foreign_key: :agent_session_activity_id, optional: true
  belongs_to :action, class_name: "AgentSessionAction", foreign_key: :agent_session_action_id, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :text, presence: true

  # Show up live at the top of the computer's feed when written.
  after_create_commit -> { broadcast_prepend_to [ agent_computer, :feed ], target: "agent_feed_posts", partial: "agent_posts/post", locals: { post: self } }

  # Newest first; posts from one run keep the order they were written in
  scope :newest_first, -> { order(posted_at: :desc, id: :asc) } # (a run's posts share a time, and are saved in order)

  # The text around its link: ["I noticed Sean asked to be added to Persona, so ", "I did that", "."]
  def parts
    before, link, after = text.partition(/\[[^\]]+\]/)
    link.present? ? [ before, link[1..-2], after ] : [ text, nil, "" ]
  end

  def screenshot
    action&.screenshot&.attached? ? action.screenshot : nil
  end
end
