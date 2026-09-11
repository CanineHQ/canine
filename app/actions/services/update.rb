class Services::Update
  extend LightService::Action

  expects :service, :params
  promises :service

  executed do |context|
    was_public = context.service.allow_public_networking?
    was_internal = context.service.internal?

    context.service.update(Service.permitted_params(context.params))
    if context.service.cron_job? && context.params[:service][:cron_schedule].present?
      context.service.cron_schedule.update(
        context.params[:service][:cron_schedule].permit(:schedule))
    end

    if !was_public && context.service.allow_public_networking?
      Domains::AttachAutoManagedDomain.execute(service: context.service)
    end

    # Update OAuth application redirect URI when domain changes
    if context.service.internal? && context.service.oauth_application.present? && context.service.auto_domain.present?
      context.service.oauth_application.update(redirect_uri: "https://#{context.service.auto_domain}/oauth2/callback")
    end

    # Schedule cleanup of auth proxy K8s resources when internal is toggled off
    if was_internal && !context.service.internal?
      Services::CleanupAuthProxyJob.perform_later(context.service)
    end

    context.service.updated!
  end
end
