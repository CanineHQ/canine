module RepositorySearchable
  extend ActiveSupport::Concern

  def index
    provider = current_user.providers.find(params[:provider_id])
    client = build_client(provider)

    @repositories = if params[:q].present?
      search_repositories(client, params[:q])
    else
      page = params[:page] || 1
      list_repositories(client, page:)
    end

    respond_to do |format|
      format.turbo_stream do
        if params[:page].to_i == 1 || params[:q].present?
          render turbo_stream: [
            turbo_stream.update("#{provider_name}-username", provider.username),
            turbo_stream.update("#{provider_name}-repositories-list", partial: "integrations/repositories/index", locals: { repositories: @repositories })
          ]
        else
          render turbo_stream: turbo_stream.append(
            "#{provider_name}-repositories-list",
            partial: "integrations/repositories/index",
            locals: { repositories: @repositories }
          )
        end
      end
    end
  end
end
