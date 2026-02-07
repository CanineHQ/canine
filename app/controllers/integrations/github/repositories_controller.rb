class Integrations::Github::RepositoriesController < ApplicationController
  def index
    provider = current_user.providers.find(params[:provider_id])
    client = Git::Github::Client.build_client(
      access_token: provider.access_token,
      api_base_url: provider.api_base_url
    )
    if params[:q].present?
      client.auto_paginate = true
      @repositories = client.repos
      @repositories = @repositories.select { |repo| repo.full_name.downcase.include?(params[:q].downcase) }
    else
      page = params[:page] || 1
      @repositories = client.repos(nil, page:)
    end

    respond_to do |format|
      format.turbo_stream do
        if params[:page].to_i == 1 || params[:q].present?
          render turbo_stream: [
            turbo_stream.update("github-username", provider.username),
            turbo_stream.update("github-repositories-list", partial: "integrations/repositories/index", locals: { repositories: @repositories })
          ]
        else
          render turbo_stream: turbo_stream.append(
            "github-repositories-list",
            partial: "integrations/repositories/index",
            locals: { repositories: @repositories }
          )
        end
      end
    end
  end
end
