class Projects::Services::OauthApplicationsController < Projects::Services::BaseController
  def create
    unless @service.oauth_application.present?
      @service.create_oauth_application!(
        name: "Auth Proxy: #{@service.name} (#{@service.project.name})",
        redirect_uri: "#{ENV.fetch('APP_HOST')}/oauth2/callback",
        scopes: "openid profile email",
        confidential: true
      )
      if @service.primary_domain.present?
        @service.oauth_application.update(redirect_uri: "https://#{@service.primary_domain}/oauth2/callback")
      end
    end

    redirect_to project_services_path(@project), notice: "SSO protection enabled for #{@service.name}."
  end

  def destroy
    @service.oauth_application&.destroy
    redirect_to project_services_path(@project), notice: "SSO protection removed from #{@service.name}."
  end
end
