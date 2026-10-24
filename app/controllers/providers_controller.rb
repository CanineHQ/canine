class ProvidersController < ApplicationController
  MAX_DISPLAYED_PROJECTS = 4

  def index
  end

  def new
    @provider = Provider.new
  end

  def create
    @provider = Provider.new(provider_params.merge(user: current_user))
    result = Providers::Create.call(@provider)
    if result.success?
      redirect_to providers_path, notice: "#{@provider.provider.titleize} credentials added"
    else
      render "new", status: :unprocessable_entity
    end
  end

  def edit
    @provider = current_user.providers.non_sso.find(params[:id])
  end

  def update
    @provider = current_user.providers.non_sso.find(params[:id])
    result = Providers::Update.call(
      @provider,
      access_token: params.dig(:provider, :access_token),
      name: params.dig(:provider, :name)
    )
    if result.success?
      Providers::SyncRegistrySecretsJob.perform_later(@provider, current_user)
      redirect_to providers_path, notice: "#{@provider.provider.titleize} token updated. Projects using it will pick it up on their next build, and their image pull secrets are being refreshed now."
    else
      render "edit", status: :unprocessable_entity
    end
  end

  def destroy
    @provider = current_user.providers.find(params[:id])
    if @provider.destroy
      redirect_to providers_path, notice: "Provider deleted"
    else
      redirect_to providers_path, alert: "Failed to delete provider"
    end
  end
  private
  def provider_params
    params.require(:provider).permit(:name, :provider, :username_param, :access_token, :registry_url)
  end
end
