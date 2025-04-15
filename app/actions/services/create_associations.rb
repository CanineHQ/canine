class Services::CreateAssociations
  extend LightService::Action

  expects :service, :params

  executed do |context|
    if context.params[:service][:cron_schedule].present?
      CronSchedule.new(
        schedule: context.params[:service][:cron_schedule][:schedule],
        service: context.service,
      )
    end
  end
end
