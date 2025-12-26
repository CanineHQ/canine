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

  enum :role, { owner: 0, admin: 1, member: 2 }

  def admin_or_owner?
    owner? || admin?
  end

  def destroyable?
    !owner?
  end
end
