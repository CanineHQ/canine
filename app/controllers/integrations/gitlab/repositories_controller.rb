class Integrations::Gitlab::RepositoriesController < ApplicationController
  def index
    provider = current_user.providers.find(params[:provider_id])
    client = Git::Gitlab::Client.build_client(
      access_token: provider.access_token,
      api_base_url: provider.api_base_url
    )

    if params[:q].present?
      @repositories = client.search_repos(params[:q])
    else
      page = params[:page] || 1
      @repositories = client.repos(page:)
    end

    respond_to do |format|
      format.turbo_stream do
        if params[:page].to_i == 1 || params[:q].present?
          render turbo_stream: [
            turbo_stream.update("gitlab-username", provider.username),
            turbo_stream.update("gitlab-repositories-list", partial: "integrations/repositories/index", locals: { repositories: @repositories })
          ]
        else
          render turbo_stream: turbo_stream.append(
            "gitlab-repositories-list",
            partial: "integrations/repositories/index",
            locals: { repositories: @repositories }
          )
        end
      end
    end
  end
end
