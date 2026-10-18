# == Schema Information
#
# Table name: agent_computer_sessions
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
#  workspace         :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  agent_computer_id :bigint           not null
#  task_id           :bigint
#
# Indexes
#
#  index_agent_computer_sessions_on_agent_computer_id   (agent_computer_id)
#  index_agent_computer_sessions_on_task_id             (task_id)
#  index_agent_computer_sessions_on_task_id_and_status  (task_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (agent_computer_id => agent_computers.id)
#  fk_rails_...  (task_id => agent_computer_tasks.id)
#
class AgentComputer::Session < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :agent_computer
  belongs_to :task, optional: true

  delegate :computer_use, to: :agent_computer
  has_many :messages, -> { order(:position) }, dependent: :destroy
  has_many :activities, -> { order(:position) }, dependent: :destroy
  has_many :actions, -> { order(:created_at) }, dependent: :destroy
  has_many :posts, dependent: :delete_all

  enum :trigger, { scheduled: 0, manual: 1 }
  enum :status, { queued: 0, running: 1, waiting_for_tool: 3, succeeded: 4, failed: 5, cancelled: 6 }

  ACTIVE = %w[queued running waiting_for_tool].freeze
  scope :active, -> { where(status: ACTIVE) }

  after_create_commit -> { broadcast_prepend_to [ task, :runs ], target: dom_id(task, :runs), partial: "agent_computers/tasks/run", locals: { session: self, animate: true } if task }
  after_create_commit -> { broadcast_prepend_to [ agent_computer, :feed ], target: "agent_feed_active", partial: "agent_computers/posts/running", locals: { session: self } }
  after_update_commit :broadcast_changes

  # A new session for a task, covering what arrived since its last successful run (window_from: nil covers everything
  # up to now, for one-off tasks with no "since last run" dimension). Sessions on a computer run side by side, each on
  # a workspace of its own (claim_workspace!); one that can't get a workspace yet waits, queued, until one frees up.
  def self.start!(task, trigger:, window_from: task.next_window_from)
    session = task.agent_computer.sessions.create!(task:, trigger:, model: task.model, window_from:, window_to: Time.current)
    task.update!(next_run_at: task.cron.next_time.to_t) if trigger.to_s == "scheduled"
    AgentSessions::TurnJob.perform_later(session)
    session
  end

  def active?
    status.in?(ACTIVE)
  end

  # Queued until a workspace frees up (rather than queued and about to start): the computer has as many runs going as
  # it takes at once.
  def waiting_in_queue?
    queued? && workspace.nil? && agent_computer.sessions.active.where.not(workspace: nil).count >= AgentComputer::PARALLEL_RUNS
  end

  # A run in progress that's done nothing for this long is probably stuck (its card says so)
  STALLED_AFTER = 10.minutes

  # When the run last moved: it started, took an action or a browser step, or the model said something
  def last_progress_at
    [ started_at || created_at, actions.maximum(:updated_at), messages.maximum(:created_at) ].compact.max
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
    task&.name || "One-off session"
  end

  # Hands a tool's result back to the model and carries on (BrowseWatchJob, DelegateWatchJob), unless the session
  # ended while the tool ran. The watch job's copy of the session can be stale by then (cancelled during a long poll),
  # so this rereads it under a row lock: resuming a cancelled session would undo the cancel. Returns whether it resumed.
  def resume_with!(content)
    resumed = with_lock do
      next false unless waiting_for_tool?

      messages.create!(position: messages.unscope(:order).maximum(:position).to_i + 1, role: "user", content:)
      running!
      true
    end
    AgentSessions::TurnJob.perform_later(self) if resumed
    resumed
  end

  # The workspace this run's windows open on, claimed before its first turn: its task's, or a free one — not the one
  # the person is looking at, nothing of theirs on it, and no other run on it (empty ones first). Under a lock on the
  # computer, so two runs starting together can't take the same one. Cleared first, of anything an earlier run left
  # there. nil while none is free, or the computer already has PARALLEL_RUNS going: the run waits until one is.
  # Raises ComputerUse::Error if the computer can't be reached.
  def claim_workspace!
    return workspace if workspace

    listing = agent_computer.computer_use.workspaces["workspaces"] unless task&.workspace
    picked = agent_computer.with_lock do
      taken = agent_computer.sessions.active.where.not(id:).where.not(workspace: nil).pluck(:workspace)
      choice = if taken.size >= AgentComputer::PARALLEL_RUNS then nil
      elsif task&.workspace then task.workspace unless taken.include?(task.workspace)
      else self.class.free_workspace(listing, taken)
      end
      update!(workspace: choice) if choice
      choice
    end
    agent_computer.clear_workspace(picked) if picked
    picked
  end

  def self.free_workspace(listing, taken)
    usable = listing.select do |w|
      w["workspace"].between?(1, 10) && !w["visible"] && taken.exclude?(w["workspace"]) && w["windows"].all? { |window| window["agent"] }
    end
    (usable.find { |w| w["windows"].empty? } || usable.first)&.dig("workspace")
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
    broadcast_replace_to self, target: dom_id(self, :timeline), partial: "agent_computers/sessions/timeline", locals: { session: self }
  end

  def broadcast_thinking(thinking)
    broadcast_replace_to self, target: dom_id(self, :thinking), partial: "agent_computers/sessions/thinking", locals: { session: self, thinking: }
  end

  private

  def broadcast_changes
    broadcast_replace_to self, target: dom_id(self, :header), partial: "agent_computers/sessions/header", locals: { session: self }
    broadcast_replace_to [ task, :runs ], target: dom_id(self), partial: "agent_computers/tasks/run", locals: { session: self } if task
    # Keep the feed's live run card in step; it renders empty once the run leaves an active state, so it drops out.
    broadcast_replace_to [ agent_computer, :feed ], target: dom_id(self, :running), partial: "agent_computers/posts/running", locals: { session: self } if saved_change_to_status?
    if summary_previously_changed? || error_previously_changed?
      broadcast_replace_to self, target: dom_id(self, :outcome), partial: "agent_computers/sessions/outcome", locals: { session: self }
    end
  end
end
