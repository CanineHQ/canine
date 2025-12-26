# == Schema Information
#
# Table name: favorites
#
#  id                :bigint           not null, primary key
#  favoriteable_type :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  favoriteable_id   :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_favorites_on_account_id    (account_id)
#  index_favorites_on_favoriteable  (favoriteable_type,favoriteable_id)
#  index_favorites_on_user_id       (user_id)
#  index_favorites_unique           (user_id,account_id,favoriteable_type,favoriteable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :account
  belongs_to :favoriteable, polymorphic: true

  validates :favoriteable_id, uniqueness: {
    scope: [ :user_id, :account_id, :favoriteable_type ],
    message: "has already been favorited"
  }
end
