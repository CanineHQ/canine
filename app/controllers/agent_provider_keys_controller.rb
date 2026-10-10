# API keys for the models agents use (OpenRouter), per account. Shown masked, never in full.
class AgentProviderKeysController < ApplicationController
  include AgentTasksFeature

  def index
    @keys = current_account.agent_provider_keys.order(:created_at)
    @key = AgentProviderKey.new
  end

  def create
    @key = current_account.agent_provider_keys.new(params.require(:agent_provider_key).permit(:provider, :name, :api_key))
    if @key.save
      redirect_to agent_provider_keys_path, notice: "Key added."
    else
      @keys = current_account.agent_provider_keys.order(:created_at)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    current_account.agent_provider_keys.find(params[:id]).destroy!
    redirect_to agent_provider_keys_path, status: :see_other, notice: "Key deleted."
  end
end
