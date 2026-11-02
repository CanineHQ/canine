module AgentTasksHelper
  # A schedule in words, as services describe cron jobs ("Runs every hour of every day"). A task composed to run now
  # has none. (Cron2English's ParseException is an Exception, not a StandardError.)
  def schedule_in_words(schedule)
    return "Runs once, when started" if schedule.blank?

    "Runs #{Cron2English.parse(schedule).join(" ")}"
  rescue StandardError, Cron2English::ParseException
    schedule
  end

  # When a task runs next, in its time zone if it has one
  def next_run_in_words(task)
    return "not enabled" unless task.enabled? && task.next_run_at

    zone = task.zone || Time.zone
    "#{task.next_run_at.in_time_zone(zone).strftime("%a %b %-d, %H:%M %Z")}, in #{time_ago_in_words(task.next_run_at)}"
  end
end
