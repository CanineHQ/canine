Rails.application.configure do
  config.good_job = {
    preserve_job_records: true,
    retry_on_unhandled_error: false,
    on_thread_error: ->(exception) { Rails.logger.error(exception) },
    execution_mode: :external,
    queues: '*',
    max_threads: 5,
    poll_interval: 30,
    shutdown_timeout: 25,
    enable_cron: true,
    cron: {
      check_health: {
        cron: "*/15 * * * *",
        class: "Scheduled::CheckHealthJob",
        description: "Check service health every 15 minutes"
      },
      fetch_metrics: {
        cron: "*/15 * * * *",
        class: "Scheduled::FetchMetricsJob",
        description: "Fetch metrics every 15 minutes"
      },
      flush_metrics: {
        cron: "0 0 * * *",
        class: "Scheduled::FlushMetricsJob",
        description: "Flush metrics daily at midnight"
      },
      cancel_hanging_builds: {
        cron: "0 * * * *",
        class: "Scheduled::CancelHangingBuildsJob",
        description: "Cancel hanging builds every hour"
      },
      cleanup_closed_pr_projects: {
        cron: "*/30 * * * *",
        class: "CleanupClosedPrProjectsJob",
        description: "Cleanup closed PR projects every 30 minutes"
      }
    }
  }
end
