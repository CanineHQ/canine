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
#  parent_id    :bigint
#  tool_call_id :string
#
# Indexes
#
#  index_agent_computer_session_actions_on_activity_id  (activity_id)
#  index_agent_computer_session_actions_on_parent_id    (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (activity_id => agent_computer_session_activities.id)
#  fk_rails_...  (parent_id => agent_computer_session_actions.id) ON DELETE => cascade
#
class AgentComputer::Session::Action < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :activity
  has_one :session, through: :activity
  # A browse's steps (browse_step) belong to it, and the timeline nests them under it
  belongs_to :parent, class_name: "AgentComputer::Session::Action", optional: true
  has_many :steps, -> { order(:created_at) }, class_name: "AgentComputer::Session::Action", foreign_key: :parent_id, inverse_of: :parent
  # Small versions for the timeline, made in the background as each screenshot is saved; the lightbox shows the original
  has_one_attached :screenshot do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 240, 135 ], format: :webp, preprocessed: true
    attachable.variant :medium, resize_to_limit: [ 960, 540 ], format: :webp, preprocessed: true
  end

  enum :status, { running: 0, done: 1, failed: 2 }

  LOOK_ONLY_ACTIONS = %w[screenshot zoom cursor_position wait].freeze

  after_create_commit lambda {
    broadcast_append_to session, target: parent ? dom_id(parent, :steps) : dom_id(activity, :actions),
                                 partial: "agent_computers/sessions/action", locals: { action: self, animate: true } unless look_only?
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
    return "Asked you: #{arguments["question"].to_s.truncate(80)}" if tool == "ask_person"
    return "Remembered: #{arguments["note"].to_s.truncate(80)}" if tool == "remember"
    return "Forgot notes about “#{arguments["text"].to_s.truncate(60)}”" if tool == "forget"

    args = arguments.except("agent_computer_id", "intent")
    detail = args.slice("action", "operation").values.first
    target = args["text"] || args["url"] || args["command"] || args["name"] || args["title"] || args["coordinate"]&.join(", ")
    [ tool.delete_prefix("computer_"), detail, target.presence && "“#{target.to_s.truncate(60)}”" ].compact.join(" ")
  end

  # Where its screenshot was taken: "before" what it says it did (the screen it decided from), or "after"
  def screenshot_moment
    tool == "browse_step" && arguments["marked"] != "after" ? "before" : "after"
  end

  # What its screenshot shows, for the lightbox: when it was taken and what the agent was doing, as [label, text] rows.
  # A browser step's come from what browser-use reported (its result text: "Before:", "Did:", "Result:", "Error:")
  def explainer
    text = result&.dig("text").to_s
    if tool == "browse_step"
      line = ->(prefix) { text.lines.find { |l| l.start_with?("#{prefix}: ") }&.delete_prefix("#{prefix}: ")&.strip }
      marked = arguments["marked"].present? ? ", with boxes where it acted" : ""
      [ [ "Screenshot", screenshot_moment == "before" ? "The page it decided from, before this step#{marked}" : "The page after this step#{marked}" ],
        [ "Goal", arguments["goal"] ], [ "Did", (Array(arguments["did"]).presence || Array(arguments["actions"])).join("; ") ],
        [ "Last step", line.("Before") ], [ "Result", line.("Result")&.truncate(400) ], [ "Error", line.("Error") ], [ "Page", arguments["url"] ] ]
    else
      [ [ "Screenshot", "The screen after this call" ], [ "Call", label ], [ "Result", text.truncate(400) ] ]
    end.select { |_, value| value.present? }
  end

  private

  # What the step did ("Clicked “Pay invoice”"); steps from before those were recorded say what it was trying to do
  def browse_step_label
    did = Array(arguments["did"]) - [ "Finished" ]
    did.any? ? did.join(" · ").truncate(120) : arguments["goal"].to_s.truncate(80).presence || "browser step"
  end

  # Morphed rather than replaced: swapping the elements wholesale blanks every image until it reloads (the page
  # flashes) and resets the thumbnail strip's scroll; a morph only changes what's new, and an <img> keeps showing
  # the old screenshot until the new one has loaded
  def broadcast_changes
    morph = { method: :morph }
    broadcast_replace_to session, target: dom_id(self), partial: "agent_computers/sessions/action", locals: { action: self }, attributes: morph unless look_only?
    broadcast_running_card # (with its thumbnail: what's on screen now)
    return unless screenshot.attached?

    broadcast_replace_to session, target: dom_id(session, :screen), partial: "agent_computers/sessions/screen", locals: { action: self }, attributes: morph
    broadcast_replace_to session, target: dom_id(activity, :shots), partial: "agent_computers/sessions/shots", locals: { activity: }, attributes: morph
  end

  # The feed's card for the run in progress: what it's doing, and when it last moved
  def broadcast_running_card
    broadcast_replace_to [ session.agent_computer, :feed ], target: dom_id(session, :running), partial: "agent_computers/posts/running", locals: { session: } if session.active?
  end
end
