# == Schema Information
#
# Table name: teams
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_teams_on_account_id           (account_id)
#  index_teams_on_account_id_and_name  (account_id,name) UNIQUE
#  index_teams_on_slug                 (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Team < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  belongs_to :account
  has_many :team_memberships, dependent: :destroy
  has_many :users, through: :team_memberships
  has_many :team_resources, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }
end
