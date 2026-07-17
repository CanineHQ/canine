class Scheduled::CheckHealthJob < ApplicationJob
  queue_as :monitoring

  def perform
    Service.where.not(service_type: :cron_job).find_each do |service|
      CheckServiceHealthJob.perform_later(service)
    end
  end
end
