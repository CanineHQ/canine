# == Schema Information
#
# Table name: shell_tokens
#
#  id         :bigint           not null, primary key
#  container  :string
#  expires_at :datetime         not null
#  namespace  :string           not null
#  pod_name   :string           not null
#  token      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_shell_tokens_on_cluster_id  (cluster_id)
#  index_shell_tokens_on_token       (token) UNIQUE
#  index_shell_tokens_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (user_id => users.id)
#
class ShellToken < ApplicationRecord
  TOKEN_TTL = 5.minutes

  # Kubernetes resource names: lowercase alphanumeric, hyphens, dots; max 253 chars
  K8S_NAME_FORMAT = /\A[a-z0-9][a-z0-9.\-]{0,251}[a-z0-9]\z/

  belongs_to :user
  belongs_to :cluster

  validates :token, :pod_name, :namespace, :expires_at, presence: true
  validates :token, uniqueness: true
  validates :pod_name, :namespace, format: { with: K8S_NAME_FORMAT, message: "must be a valid Kubernetes resource name" }
  validates :container, format: { with: K8S_NAME_FORMAT, message: "must be a valid Kubernetes resource name" }, allow_blank: true

  before_validation :generate_token, if: :new_record?
  before_validation :set_expiry, if: :new_record?

  scope :active, -> { where("expires_at > ?", Time.current) }

  def expired?
    expires_at < Time.current
  end

  def self.generate_for(user:, cluster:, pod_name:, namespace:, container: nil)
    create!(
      user: user,
      cluster: cluster,
      pod_name: pod_name,
      namespace: namespace,
      container: container
    )
  end

  def self.cleanup_expired!
    where("expires_at < ?", Time.current).delete_all
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at = TOKEN_TTL.from_now
  end
end
