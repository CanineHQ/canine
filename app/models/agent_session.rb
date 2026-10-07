# == Schema Information
#
# Table name: agent_sessions
#
#  id                :bigint           not null, primary key
#  cached_tokens     :bigint           default(0), not null
#  cost_usd          :decimal(10, 6)   default(0.0), not null
#  error             :text
#  finished_at       :datetime
#  input_tokens      :integer          default(0), not null
#  model             :string           not null
#  notes             :text
#  notes_through     :integer
#  output_tokens     :integer          default(0), not null
#  provider          :string
#  started_at        :datetime
#  status            :integer          default("queued"), not null
#  summary           :text
#  trigger           :integer          default("scheduled"), not null
#  turns             :integer          default(0), not null
#  window_from       :datetime
#  window_to         :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  agent_computer_id :bigint           not null
#  agent_task_id     :bigint
#
# Indexes
#
#  index_agent_sessions_on_agent_computer_id         (agent_computer_id)
#  index_agent_sessions_on_agent_task_id             (agent_task_id)
#  index_agent_sessions_on_agent_task_id_and_status  (agent_task_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (agent_computer_id => agent_computers.id)
#  fk_rails_...  (agent_task_id => agent_tasks.id)
#
class AgentSession < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :agent_computer
  belongs_to :agent_task, optional: true

  delegate :computer_use, to: :agent_computer
  has_many :messages, -> { order(:position) }, class_name: "AgentSessionMessage", dependent: :destroy
  has_many :activities, -> { order(:position) }, class_name: "AgentSessionActivity", dependent: :destroy
  has_many :actions, -> { order(:created_at) }, class_name: "AgentSessionAction", dependent: :destroy
  has_many :posts, class_name: "AgentPost", dependent: :delete_all

  enum :trigger, { scheduled: 0, manual: 1 }
  enum :status, { queued: 0, running: 1, waiting_for_human: 2, waiting_for_tool: 3, succeeded: 4, failed: 5, cancelled: 6 }

  ACTIVE = %w[queued running waiting_for_human waiting_for_tool].freeze
  scope :active, -> { where(status: ACTIVE) }

  after_create_commit -> { broadcast_prepend_to [ agent_task, :runs ], target: dom_id(agent_task, :runs), partial: "agent_tasks/run", locals: { session: self, animate: true } if agent_task }
  after_update_commit :broadcast_changes

  # A new session for a task, covering what arrived since its last successful run (window_from: nil covers everything
  # up to now, for one-off tasks with no "since last run" dimension), and its first turn
  def self.start!(task, trigger:, window_from: task.next_window_from)
    session = task.agent_computer.agent_sessions.create!(agent_task: task, trigger:, model: task.model,
                                                         window_from:, window_to: Time.current)
    task.update!(next_run_at: task.cron.next_time.to_t) if trigger.to_s == "scheduled"
    AgentSessions::TurnJob.perform_later(session)
    session
  end

  def active?
    status.in?(ACTIVE)
  end

  def current_activity
    activities.last
  end

  Run = Struct.new(:name, :status, :started_at, :finished_at, :duration, keyword_init: true)

  # This session as a row of shared/_run_history, like a cron job's runs
  def as_run
    status = { "succeeded" => :succeeded, "failed" => :failed, "cancelled" => :cancelled }.fetch(self.status, :running)
    Run.new(name: plain_summary.truncate(100).presence || "Run #{created_at.strftime("%b %-d, %H:%M")}",
            status:, started_at: started_at || created_at, finished_at:,
            duration: started_at && finished_at ? (finished_at - started_at).round : nil)
  end

  # The summary (or error) as one line of plain text, without its markdown, for lists
  def plain_summary
    (summary || error).to_s.gsub(/[*_`#>]+|^\s*[-+]\s+/, "").gsub(/\[([^\]]*)\]\([^)]*\)/, '\1').squish
  end

  def title
    agent_task&.name || "One-off session"
  end

  def finish!(status, summary: nil, error: nil)
    update!(status:, summary:, error:, finished_at: Time.current)
    current_activity&.finish!
    AgentLoop::Tidy.enqueue(self, all: true)
    AgentSessions::WrapupJob.perform_later(self) # a summary if it has none, and close the windows it opened
    AgentSessions::PostJob.set(wait: AgentSessions::PostJob::WAIT).perform_later(self) # what it did, for the feed
    broadcast_thinking(false)
  end

  # The "thinking" indicator while a model call is in flight
  # The chapters and the progress strip, re-drawn after tidying (activities themselves stream in one by one)
  def broadcast_timeline
    broadcast_replace_to self, target: dom_id(self, :timeline), partial: "agent_sessions/timeline", locals: { session: self }
  end

  def broadcast_thinking(thinking)
    broadcast_replace_to self, target: dom_id(self, :thinking), partial: "agent_sessions/thinking", locals: { session: self, thinking: }
  end

  private

  def broadcast_changes
    broadcast_replace_to self, target: dom_id(self, :header), partial: "agent_sessions/header", locals: { session: self }
    broadcast_replace_to [ agent_task, :runs ], target: dom_id(self), partial: "agent_tasks/run", locals: { session: self } if agent_task
    if summary_previously_changed? || error_previously_changed?
      broadcast_replace_to self, target: dom_id(self, :outcome), partial: "agent_sessions/outcome", locals: { session: self }
    end
  end
end
