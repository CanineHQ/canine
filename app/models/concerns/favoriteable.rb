# frozen_string_literal: true

module Favoriteable
  extend ActiveSupport::Concern

  included do
    has_many :favorites, as: :favoriteable, dependent: :destroy
  end

  def favorited_by?(user, account)
    favorites.exists?(user: user, account: account)
  end
end
