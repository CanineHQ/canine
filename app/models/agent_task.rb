# == Schema Information
#
# Table name: agent_tasks
#
#  id                :bigint           not null, primary key
#  enabled           :boolean          default(FALSE), not null
#  instruction       :text             not null
#  model             :string           not null
#  name              :string           not null
#  next_run_at       :datetime
#  schedule          :string
#  spec              :jsonb            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  agent_computer_id :bigint           not null
#
# Indexes
#
#  index_agent_tasks_on_agent_computer_id        (agent_computer_id)
#  index_agent_tasks_on_enabled_and_next_run_at  (enabled,next_run_at)
#
# Foreign Keys
#
#  fk_rails_...  (agent_computer_id => agent_computers.id)
#
class AgentTask < ApplicationRecord
  FEATURE_FLAG = :agent_tasks

  # Whether the account has agent tasks and sessions (a Flipper flag while the feature is new)
  def self.enabled_for?(account)
    Flipper.enabled?(FEATURE_FLAG, account)
  end

  DEFAULT_MODEL = "openai/gpt-5.1"

  belongs_to :agent_computer
  has_many :sessions, class_name: "AgentSession", dependent: :destroy

  validates :name, :instruction, :model, presence: true
  validate :schedule_is_cron
  validate :enabled_needs_a_schedule

  before_save :schedule_next_run, if: -> { will_save_change_to_schedule? || (will_save_change_to_enabled? && enabled?) }

  scope :due, -> { where(enabled: true).where(next_run_at: ..Time.current) }

  # A task with a schedule recurs on it; without one it's a one-off the person runs when they want.
  def recurring? = schedule.present?

  def cron
    Fugit.parse_cron(schedule)
  end

  def schedule_next_run
    self.next_run_at = cron&.next_time&.to_t
  end

  def last_session
    sessions.order(created_at: :desc).first
  end

  # The window a new run covers starts where the last successful one ended, so each message is seen by one run
  def next_window_from
    sessions.succeeded.maximum(:window_to) || 1.hour.ago
  end

  private

  def schedule_is_cron
    errors.add(:schedule, "isn't a cron schedule, e.g. 0 * * * *") if schedule.present? && cron.nil?
  end

  def enabled_needs_a_schedule
    errors.add(:schedule, "is needed to run a task on a schedule") if enabled? && schedule.blank?
  end
end
