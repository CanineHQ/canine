# == Schema Information
#
# Table name: sandbox_proxy_tokens
#
#  id               :bigint           not null, primary key
#  connected_at     :datetime
#  expires_at       :datetime         not null
#  namespace        :string           not null
#  pod_name         :string           not null
#  token            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  agent_sandbox_id :bigint           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_sandbox_proxy_tokens_on_agent_sandbox_id  (agent_sandbox_id)
#  index_sandbox_proxy_tokens_on_token             (token) UNIQUE
#  index_sandbox_proxy_tokens_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (agent_sandbox_id => agent_sandboxes.id)
#  fk_rails_...  (user_id => users.id)
#
class SandboxProxyToken < ApplicationRecord
  TOKEN_TTL = 5.minutes

  belongs_to :agent_sandbox
  belongs_to :user

  validates :token, :pod_name, :namespace, :expires_at, presence: true
  validates :token, uniqueness: true

  before_validation :generate_token, if: :new_record?
  before_validation :set_expiry, if: :new_record?

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :connected, -> { where.not(connected_at: nil) }
  scope :pending, -> { where(connected_at: nil) }

  def expired?
    expires_at < Time.current
  end

  def mark_connected!
    update!(connected_at: Time.current)
  end

  def self.generate_for(agent_sandbox:, user:, pod_name:, namespace:)
    create!(
      agent_sandbox: agent_sandbox,
      user: user,
      pod_name: pod_name,
      namespace: namespace
    )
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at = TOKEN_TTL.from_now
  end
end
