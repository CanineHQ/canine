# == Schema Information
#
# Table name: agent_computer_posts
#
#  id                   :bigint           not null, primary key
#  kind                 :string           not null
#  position             :integer          default(0), not null
#  posted_at            :datetime         not null
#  text                 :text             not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  activity_id          :bigint
#  screenshot_action_id :bigint
#  session_id           :bigint           not null
#
# Indexes
#
#  index_agent_computer_posts_on_activity_id           (activity_id)
#  index_agent_computer_posts_on_posted_at             (posted_at)
#  index_agent_computer_posts_on_screenshot_action_id  (screenshot_action_id)
#  index_agent_computer_posts_on_session_id            (session_id)
#
# Foreign Keys
#
#  fk_rails_...  (activity_id => agent_computer_session_activities.id) ON DELETE => nullify
#  fk_rails_...  (screenshot_action_id => agent_computer_session_actions.id) ON DELETE => nullify
#  fk_rails_...  (session_id => agent_computer_sessions.id)
#
class AgentComputer::Post < ApplicationRecord
  KINDS = %w[done found needs_you problem].freeze

  belongs_to :session
  has_one :agent_computer, through: :session
  # The step it's about (none for a run that stopped before taking any: its "problem" post), and the screenshot shown
  # with it if any: the session's (AgentComputer::Session::*), which the name alone wouldn't find from here
  belongs_to :activity, class_name: "AgentComputer::Session::Activity", optional: true
  belongs_to :screenshot_action, class_name: "AgentComputer::Session::Action", optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :text, presence: true

  # Show up live at the top of the computer's feed when written.
  after_create_commit -> { broadcast_prepend_to [ agent_computer, :feed ], target: "agent_feed_posts", partial: "agent_computers/posts/post", locals: { post: self } }

  # Newest first; posts from one run keep the order they were written in
  scope :newest_first, -> { order(posted_at: :desc, id: :asc) } # (a run's posts share a time, and are saved in order)

  # The text around its link: ["I noticed Sean asked to be added to Persona, so ", "I did that", "."]
  def parts
    before, link, after = text.partition(/\[[^\]]+\]/)
    link.present? ? [ before, link[1..-2], after ] : [ text, nil, "" ]
  end

  def screenshot
    screenshot_action&.screenshot&.attached? ? screenshot_action.screenshot : nil
  end
end
