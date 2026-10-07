module AgentTasksHelper
  # A schedule in words, as services describe cron jobs ("Runs every hour of every day")
  def schedule_in_words(schedule)
    "Runs #{Cron2English.parse(schedule).join(" ")}"
  rescue StandardError
    schedule
  end

  # When a task runs next, in its time zone if it has one
  def next_run_in_words(task)
    return "not enabled" unless task.enabled? && task.next_run_at

    zone = ActiveSupport::TimeZone[task.spec.to_h["time_zone"].to_s] || Time.zone
    "#{task.next_run_at.in_time_zone(zone).strftime("%a %b %-d, %H:%M %Z")}, in #{time_ago_in_words(task.next_run_at)}"
  end
end
