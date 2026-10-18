# == Schema Information
#
# Table name: agent_computer_session_actions
#
#  id           :bigint           not null, primary key
#  arguments    :jsonb            not null
#  duration_ms  :integer
#  result       :jsonb
#  started_at   :datetime
#  status       :integer          default("running"), not null
#  tool         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  activity_id  :bigint           not null
#  tool_call_id :string
#
# Indexes
#
#  index_agent_computer_session_actions_on_activity_id  (activity_id)
#
# Foreign Keys
#
#  fk_rails_...  (activity_id => agent_computer_session_activities.id)
#
class AgentComputer::Session::Action < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :activity
  has_one :session, through: :activity
  # Small versions for the timeline, made in the background as each screenshot is saved; the lightbox shows the original
  has_one_attached :screenshot do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 240, 135 ], format: :webp, preprocessed: true
    attachable.variant :medium, resize_to_limit: [ 960, 540 ], format: :webp, preprocessed: true
  end

  enum :status, { running: 0, done: 1, failed: 2, blocked: 3 }

  LOOK_ONLY_ACTIONS = %w[screenshot zoom cursor_position wait].freeze

  after_create_commit lambda {
    broadcast_append_to session, target: dom_id(activity, :actions), partial: "agent_computers/sessions/action", locals: { action: self, animate: true } unless look_only?
    broadcast_running_card
  }
  after_update_commit :broadcast_changes

  # A short, readable description for the timeline: "left_click (640, 360)", "type “hello”", "find link “Learn more”"
  def look_only?
    tool == "computer_screenshot" || (tool == "computer_action" && arguments["action"].in?(LOOK_ONLY_ACTIONS))
  end

  def label
    return "browse: #{arguments["task"].to_s.truncate(70)}" if tool == "browse"
    return browse_step_label if tool == "browse_step"

    args = arguments.except("agent_computer_id", "intent")
    detail = args.slice("action", "operation").values.first
    target = args["text"] || args["url"] || args["command"] || args["name"] || args["title"] || args["coordinate"]&.join(", ")
    [ tool.delete_prefix("computer_"), detail, target.presence && "“#{target.to_s.truncate(60)}”" ].compact.join(" ")
  end

  # Where its screenshot was taken: "before" what it says it did (the screen it decided from), or "after"
  def screenshot_moment
    tool == "browse_step" && arguments["marked"] != "after" ? "before" : "after"
  end

  private

  # What the step did ("Clicked “Pay invoice”"); steps from before those were recorded say what it was trying to do
  def browse_step_label
    did = Array(arguments["did"]) - [ "Finished" ]
    did.any? ? did.join(" · ").truncate(120) : arguments["goal"].to_s.truncate(80).presence || "browser step"
  end

  def broadcast_changes
    broadcast_replace_to session, target: dom_id(self), partial: "agent_computers/sessions/action", locals: { action: self } unless look_only?
    broadcast_running_card # (with its thumbnail: what's on screen now)
    return unless screenshot.attached?

    broadcast_replace_to session, target: dom_id(session, :screen), partial: "agent_computers/sessions/screen", locals: { action: self }
    broadcast_replace_to session, target: dom_id(activity, :shots), partial: "agent_computers/sessions/shots", locals: { activity: }
  end

  # The feed's card for the run in progress: what it's doing, and when it last moved
  def broadcast_running_card
    broadcast_replace_to [ session.agent_computer, :feed ], target: dom_id(session, :running), partial: "agent_computers/posts/running", locals: { session: } if session.active?
  end
end
