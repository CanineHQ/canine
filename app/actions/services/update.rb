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

    # Manage OAuth application for internal auth proxy
    if context.service.internal? && !was_internal
      unless context.service.oauth_application.present?
        context.service.create_oauth_application!(
          name: "Auth Proxy: #{context.service.name} (#{context.service.project.name})",
          redirect_uri: "#{ENV.fetch('APP_HOST')}/oauth2/callback",
          scopes: "openid profile",
          confidential: true
        )
      end
    elsif was_internal && !context.service.internal?
      context.service.oauth_application&.destroy
    elsif context.service.internal? && context.service.oauth_application.present? && context.service.auto_domain.present?
      context.service.oauth_application.update(redirect_uri: "https://#{context.service.auto_domain}/oauth2/callback")
    end

    context.service.updated!
  end
end
