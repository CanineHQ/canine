class AddOns::OauthApplicationsController < AddOns::BaseController
  def create
    unless @add_on.oauth_application.present?
      @add_on.create_oauth_application!(
        name: "Auth Proxy: #{@add_on.name}",
        redirect_uri: "#{ENV.fetch('APP_HOST')}/oauth2/callback",
        scopes: "openid profile email",
        confidential: true
      )
    end

    redirect_to edit_add_on_path(@add_on), notice: "SSO protection enabled."
  end

  def destroy
    was_internal = @add_on.internal?
    @add_on.oauth_application&.destroy

    if was_internal && @add_on.installed?
      AddOns::CleanupAuthProxyJob.perform_later(@add_on)
    end

    redirect_to edit_add_on_path(@add_on), notice: "SSO protection removed."
  end
end
