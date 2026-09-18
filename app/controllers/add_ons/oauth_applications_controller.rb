class AddOns::OauthApplicationsController < AddOns::BaseController
  def create
    InternalSSO::Enable.execute(protectable: @add_on)
    InternalSSO::DeployAddOnProxy.execute(add_on: @add_on, connection: active_connection)

    redirect_to edit_add_on_path(@add_on), notice: "SSO protection enabled."
  end

  def destroy
    InternalSSO::Disable.execute(protectable: @add_on)
    InternalSSO::CleanupAddOnProxy.execute(add_on: @add_on)

    redirect_to edit_add_on_path(@add_on), notice: "SSO protection removed."
  end
end
