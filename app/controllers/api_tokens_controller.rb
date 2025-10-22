class ApiTokensController < ApplicationController
  def new
    @api_token = ApiToken.new(user: current_user)
  end

  def create
    if ApiToken.create(api_token_params.merge(user: current_user))
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

  def api_token_params
    params.require(:api_token).permit(:expires_at)
  end
end
