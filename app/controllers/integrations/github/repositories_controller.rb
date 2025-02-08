class Integrations::Github::RepositoriesController < ApplicationController
  def index
    client = Octokit::Client.new(access_token: current_account.github_provider.access_token)
    if params[:q].present?
      client.auto_paginate = true
      @repositories = client.repos(current_account.github_username)
      @repositories = @repositories.select { |repo| repo.full_name.downcase.include?(params[:q].downcase) }
    else
      page = params[:page] || 1
      @repositories = client.repos(current_account.github_username, page:)
    end

    respond_to do |format|
      format.turbo_stream do
        if params[:page].to_i == 1 || params[:q].present?
          render turbo_stream: turbo_stream.update(
            "repositories-list",
            partial: "index",
            locals: { repositories: @repositories }
          )
        else
          render turbo_stream: turbo_stream.append(
            "repositories-list",
            partial: "index",
            locals: { repositories: @repositories }
          )
        end
      end
    end
  end
end
