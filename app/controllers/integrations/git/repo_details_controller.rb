class Integrations::Git::RepoDetailsController < ApplicationController
  def branches
    client = build_client

    if params[:q].present?
      branch_list = client.search_branches(params[:q])
      render json: { branches: branch_list }
    else
      branch_list = client.branches
      default = client.default_branch
      render json: { branches: branch_list, default_branch: default }
    end
  rescue => e
    render json: { branches: [], default_branch: nil, error: e.message }, status: :unprocessable_entity
  end

  def file_tree
    client = build_client
    branch = params[:branch].presence || client.default_branch
    entries = client.file_tree(branch).sort_by { |e| e[:path] }

    render json: { entries: entries }
  rescue => e
    render json: { entries: [], error: e.message }, status: :unprocessable_entity
  end

  private

  def build_client
    provider = current_user.providers.find(params[:provider_id])
    repository_url = params[:repository_url]
    Git::Client.from_provider(provider: provider, repository_url: repository_url)
  end
end
