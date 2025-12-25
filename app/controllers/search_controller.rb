class SearchController < ApplicationController
  def index
    @result = GlobalSearch::Search.execute(account_user: current_account_user, query: params[:q], limit: 5)
    @query = params[:q].to_s.strip
  end
end
