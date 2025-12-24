# frozen_string_literal: true

module Favorites
  class Toggle
    extend LightService::Action

    expects :user, :account, :favoriteable
    promises :favorite, :action_taken

    executed do |context|
      existing = Favorite.find_by(
        user: context.user,
        account: context.account,
        favoriteable: context.favoriteable
      )

      if existing
        existing.destroy
        context.favorite = nil
        context.action_taken = :removed
      else
        context.favorite = Favorite.create!(
          user: context.user,
          account: context.account,
          favoriteable: context.favoriteable
        )
        context.action_taken = :added
      end
    end
  end
end
