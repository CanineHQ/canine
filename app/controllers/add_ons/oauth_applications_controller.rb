class AddOns::OauthApplicationsController < AddOns::BaseController
  def create
    InternalSso::Enable.execute(protectable: @add_on)
    InternalSso::DeployAddOnProxy.execute(add_on: @add_on, connection: active_connection)

    redirect_to edit_add_on_path(@add_on), notice: "SSO protection enabled."
  end

  def destroy
    InternalSso::Disable.execute(protectable: @add_on)
    InternalSso::CleanupAddOnProxy.execute(add_on: @add_on)

    redirect_to edit_add_on_path(@add_on), notice: "SSO protection removed."
  end
end
