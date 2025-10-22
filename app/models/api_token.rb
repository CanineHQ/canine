# == Schema Information
#
# Table name: api_tokens
#
#  id           :bigint           not null, primary key
#  access_token :string           not null
#  expires_at   :datetime
#  last_used_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_api_tokens_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ApiToken < ApplicationRecord
  belongs_to :user
  validates :user, :access_token, presence: true
  validates :access_token, uniqueness: { scope: :user_id }

  before_validation :generate_token, if: :new_record?

  def generate_token
    self.access_token = SecureRandom.hex(16)
  end

  def expired?
    return false if expires_at.nil?

    expires_at < Time.zone.now
  end
end
