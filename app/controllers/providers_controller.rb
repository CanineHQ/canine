class ProvidersController < ApplicationController
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
    params.require(:provider).permit(:provider, :username_param, :access_token, :registry_url)
  end
end
