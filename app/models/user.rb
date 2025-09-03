# == Schema Information
#
# Table name: users
#
#  id                         :bigint           not null, primary key
#  admin                      :boolean          default(FALSE)
#  announcements_last_read_at :datetime
#  email                      :string           default(""), not null
#  encrypted_password         :string           default(""), not null
#  first_name                 :string
#  last_name                  :string
#  remember_created_at        :datetime
#  reset_password_sent_at     :datetime
#  reset_password_token       :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :recoverable
  devise :database_authenticatable, :registerable, :rememberable, :validatable, :omniauthable

  has_one_attached :avatar
  has_person_name

  before_save :downcase_email

  has_many :account_users, dependent: :destroy
  has_many :accounts, through: :account_users, dependent: :destroy
  has_many :owned_accounts, class_name: "Account", foreign_key: "owner_id", dependent: :destroy

  has_many :providers, dependent: :destroy
  has_many :clusters, through: :accounts
  has_many :build_clouds, through: :clusters
  has_many :projects, through: :accounts
  has_many :add_ons, through: :accounts
  has_many :services, through: :accounts
  attr_readonly :admin

  # has_many :notifications, as: :recipient, dependent: :destroy, class_name: "Noticed::Notification"
  # has_many :notification_mentions, as: :record, dependent: :destroy, class_name: "Noticed::Event"

  def github_provider
    providers.find_by(provider: "github")
  end

  def portainer_jwt
    return @portainer_jwt if @portainer_jwt
    @portainer_jwt = providers.find_by(provider: "portainer")&.access_token
  end

  private

  def downcase_email
    self.email = email.downcase
  end
end
