class Projects::CreateAssociations
  extend LightService::Action

  expects :project, :params

  executed do |context|
    if context.params[:cron_schedule].present?
      CronSchedule.create(schedule: context.params[:cron_schedule], project: context.project)
    end
  end
end