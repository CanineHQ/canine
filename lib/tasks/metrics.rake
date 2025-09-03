namespace :metrics do
  desc "Query the web services to make sure they are healthy"
  task check_health: :environment do
    Scheduled::CheckHealthJob.perform_now
  end

  desc "Poll Kubernetes cluster metrics"
  task fetch: :environment do |_, args|
    user_id = args[:user_id] || 1
    Scheduled::FetchMetricsJob.perform_now(user_id)
  end

  desc "Flush metrics older than 1 week"
  task flush: :environment do |_, args|
    Scheduled::FlushMetricsJob.perform_now
  end
end
