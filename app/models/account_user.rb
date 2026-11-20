# == Schema Information
#
# Table name: account_users
#
#  id         :bigint           not null, primary key
#  role       :integer          default("member"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_account_users_on_account_id  (account_id)
#  index_account_users_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class AccountUser < ApplicationRecord
  belongs_to :user
  belongs_to :account

  has_many :agent_computers, dependent: :destroy

  enum :role, { owner: 0, admin: 1, member: 2 }

  def admin_or_owner?
    owner? || admin?
  end

  validate :keep_an_admin_or_owner, on: :update
  before_destroy :keep_an_admin_or_owner_on_destroy

  def destroyable?
    !owner?
  end

  # True when no other owner or admin would remain on the account if this record lost its role or were removed
  def last_admin_or_owner?
    admin_or_owner? && !account.account_users.where.not(id: id).where(role: [ :owner, :admin ]).exists?
  end

  private

  def keep_an_admin_or_owner
    return unless role_changed? && role_was.in?(%w[owner admin]) && !admin_or_owner?
    return unless account.account_users.where.not(id: id).where(role: [ :owner, :admin ]).empty?

    errors.add(:base, "Account must keep at least one owner or admin")
  end

  def keep_an_admin_or_owner_on_destroy
    return if destroyed_by_association
    return unless last_admin_or_owner?

    errors.add(:base, "Account must keep at least one owner or admin")
    throw :abort
  end
end
