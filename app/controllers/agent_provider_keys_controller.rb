# API keys for the models agents use (OpenRouter), per account. Shown masked, never in full.
class AgentProviderKeysController < AgentComputers::BaseController
  skip_before_action :set_agent_computer # the account's keys, not one computer's

  def index
    @keys = current_account.agent_provider_keys.order(:created_at)
    @key = AgentProviderKey.new
  end

  def create
    @key = current_account.agent_provider_keys.new(params.require(:agent_provider_key).permit(:provider, :name, :api_key))
    if @key.save
      redirect_to agent_provider_keys_path, notice: "#{AgentProviderKey::PROVIDERS[@key.provider]} key #{@key.name.presence || @key.masked} saved. Agents will use it to call models from now on."
    else
      @keys = current_account.agent_provider_keys.order(:created_at)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    key = current_account.agent_provider_keys.find(params[:id])
    key.destroy!
    redirect_to agent_provider_keys_path, status: :see_other, notice: "#{AgentProviderKey::PROVIDERS[key.provider]} key #{key.name.presence || key.masked} deleted."
  end
end
