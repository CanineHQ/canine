# frozen_string_literal: true

module Favorites
  class ForUser
    extend LightService::Action

    expects :user, :account
    promises :favorited_projects, :favorited_clusters, :favorited_add_ons

    executed do |context|
      favorites = Favorite.where(user: context.user, account: context.account)

      context.favorited_projects = Project
        .joins(:cluster)
        .where(clusters: { account_id: context.account.id })
        .where(id: favorites.where(favoriteable_type: "Project").select(:favoriteable_id))
        .order(name: :asc)

      context.favorited_clusters = Cluster
        .where(account_id: context.account.id)
        .where(id: favorites.where(favoriteable_type: "Cluster").select(:favoriteable_id))
        .order(name: :asc)

      context.favorited_add_ons = AddOn
        .joins(:cluster)
        .where(clusters: { account_id: context.account.id })
        .where(id: favorites.where(favoriteable_type: "AddOn").select(:favoriteable_id))
        .order(name: :asc)
    end
  end
end
