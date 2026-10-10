class ApiTokensController < ApplicationController
  def new
    @api_token = ApiToken.new(user: current_user, name: params[:name])
  end

  def create
    @api_token = ApiToken.new(api_token_params.merge(user: current_user))
    if @api_token.save
      redirect_to api_tokens_path, notice: "API token saved"
    else
      render "new", status: :unprocessable_entity
    end
  end

  def destroy
    @api_token = current_user.api_tokens.find(params[:id])
    if @api_token.destroy
      redirect_to api_tokens_path, notice: "API token deleted"
    else
      redirect_to api_tokens_path, alert: "Failed to delete API token"
    end
  end

  private

  def api_token_params
    params.require(:api_token).permit(:name, :expires_at)
  end
end
