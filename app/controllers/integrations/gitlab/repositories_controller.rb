class Integrations::Gitlab::RepositoriesController < ApplicationController
  include RepositorySearchable

  private

  def provider_name = "gitlab"

  def build_client(provider)
    Git::Gitlab::Client.build_client(
      access_token: provider.access_token,
      api_base_url: provider.api_base_url
    )
  end

  def search_repositories(client, query)
    client.search_repos(query)
  end

  def list_repositories(client, page:)
    client.repos(page:)
  end
end
