# frozen_string_literal: true

module GlobalSearch
  class Search
    extend LightService::Action

    expects :account_user, :query, :limit

    promises :projects, :clusters, :add_ons

    executed do |context|
      query = context.query.to_s.strip
      limit = context.limit
      params = { q: query }

      if query.blank?
        context.projects = []
        context.clusters = []
        context.add_ons = []
        next
      end

      context.projects = Projects::List.call(account_user: context.account_user, params: params)
                                       .projects
                                       .includes(:cluster)
                                       .limit(limit)

      context.clusters = Clusters::List.call(account_user: context.account_user, params: params)
                                       .clusters
                                       .limit(limit)

      context.add_ons = AddOns::List.call(account_user: context.account_user, params: params)
                                    .add_ons
                                    .includes(:cluster)
                                    .limit(limit)
    end
  end
end
