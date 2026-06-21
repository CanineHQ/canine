# == Schema Information
#
# Table name: users
#
#  id                         :bigint           not null, primary key
#  admin                      :boolean          default(FALSE)
#  announcements_last_read_at :datetime
#  consumed_timestep          :integer
#  email                      :string           default(""), not null
#  encrypted_password         :string           default(""), not null
#  first_name                 :string
#  invitation_accepted_at     :datetime
#  invitation_created_at      :datetime
#  invitation_limit           :integer
#  invitation_sent_at         :datetime
#  invitation_token           :string
#  invitations_count          :integer          default(0)
#  invited_by_type            :string
#  last_name                  :string
#  otp_backup_codes           :string           is an Array
#  otp_required_for_login     :boolean
#  otp_secret                 :string
#  password_change_required   :boolean          default(FALSE)
#  remember_created_at        :datetime
#  reset_password_sent_at     :datetime
#  reset_password_token       :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  invited_by_id              :bigint
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_invitation_token      (invitation_token) UNIQUE
#  index_users_on_invited_by            (invited_by_type,invited_by_id)
#  index_users_on_invited_by_id         (invited_by_id)
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :recoverable
  devise :invitable, :two_factor_authenticatable, :two_factor_backupable,
         :registerable, :rememberable, :validatable, :omniauthable,
         otp_number_of_backup_codes: 10

  has_one_attached :avatar
  has_person_name

  before_save :downcase_email

  has_many :account_users, dependent: :destroy
  has_many :accounts, through: :account_users, dependent: :destroy
  has_many :owned_accounts, class_name: "Account", foreign_key: "owner_id", dependent: :destroy
  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships

  has_many :providers, dependent: :destroy
  has_many :clusters, through: :accounts
  has_many :build_clouds, through: :clusters
  has_many :projects, through: :accounts
  has_many :add_ons, through: :accounts
  has_many :services, through: :accounts
  has_many :api_tokens, dependent: :destroy
  has_many :favorites, dependent: :destroy

  # Doorkeeper
  has_many :access_grants,
            class_name: 'Doorkeeper::AccessGrant',
            foreign_key: :resource_owner_id,
            dependent: :delete_all # or :destroy if you need callbacks

  has_many :access_tokens,
            class_name: 'Doorkeeper::AccessToken',
            foreign_key: :resource_owner_id,
            dependent: :delete_all # or :destroy if you need callbacks

  attr_readonly :admin

  def self.ransackable_attributes(auth_object = nil)
    %w[email first_name last_name created_at]
  end

  # has_many :notifications, as: :recipient, dependent: :destroy, class_name: "Noticed::Notification"
  # has_many :notification_mentions, as: :record, dependent: :destroy, class_name: "Noticed::Event"

  def github_provider
    providers.find_by(provider: "github")
  end

  def stack_manager_access_token(stack_manager)
    return nil unless stack_manager
    provider_name = stack_manager.provider_name
    return nil unless provider_name
    providers.find_by(provider: provider_name)&.access_token
  end

  def portainer_access_token
    return @portainer_access_token if @portainer_access_token
    @portainer_access_token = providers.find_by(provider: "portainer")&.access_token
  end

  def two_factor_qr_code_svg
    issuer = "Canine"
    uri = otp_provisioning_uri(email, issuer: issuer)
    qrcode = RQRCode::QRCode.new(uri)
    qrcode.as_svg(module_size: 6, standalone: true, use_path: false, fill: "fff", color: "000", shape_rendering: "crispEdges")
  end

  def needs_stack_manager_credential?(account)
    sm = account.stack_manager
    sm.present? &&
      sm.enable_role_based_access_control? &&
      stack_manager_access_token(sm).blank?
  end

  private

  def downcase_email
    self.email = email.downcase
  end
end
