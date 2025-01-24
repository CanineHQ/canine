class Integrations::Github::RepositoriesController < ApplicationController
  def index
    response = RestClient.get('https://api.github.com/user/repos', {
      Authorization: "token #{current_account.github_provider.access_token}"
    })
    @repositories = JSON.parse(response.body)

    respond_to do |format|
      format.html { render partial: 'index', locals: { repositories: @repositories } }
    end
  end
end
