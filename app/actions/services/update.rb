class Services::Update
  extend LightService::Action

  expects :service, :params
  promises :service

  executed do |context|
    context.service.update(Service.permitted_params(context.params))
    if context.service.cron_job?
      context.service.cron_schedule.update(context.params[:service][:cron_schedule].permit(:schedule))
    end
    context.service.updated!
  end
end
