class Integrations::Github::RepositoriesController < ApplicationController
  include RepositorySearchable

  private

  def provider_name = "github"

  def build_client(provider)
    Git::Github::Client.build_client(
      access_token: provider.access_token,
      api_base_url: provider.api_base_url
    )
  end

  def search_repositories(client, query)
    client.search_repos("#{query} in:name fork:true", per_page: 30).items
  end

  def list_repositories(client, page:)
    client.repos(nil, page:)
  end
end
