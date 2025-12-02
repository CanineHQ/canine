# == Schema Information
#
# Table name: ldap_configurations
#
#  id                    :bigint           not null, primary key
#  allow_anonymous_reads :boolean          default(FALSE)
#  base_dn               :string           not null
#  bind_dn               :string
#  bind_password         :string
#  email_attribute       :string           default("mail")
#  encryption            :integer          not null
#  filter                :string
#  host                  :string           not null
#  name_attribute        :string           default("cn")
#  port                  :integer          default(389), not null
#  uid_attribute         :string           default("uid"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class LDAPConfiguration < ApplicationRecord
  has_one :sso_provider, as: :configuration, dependent: :destroy
  has_one :account, through: :sso_provider

  enum :encryption, { plain: 0, simple_tls: 1, start_tls: 2 }

  validates :host, presence: true
  validates :port, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :base_dn, presence: true
  validates :uid_attribute, presence: true
  validates_presence_of :bind_dn, if: :allow_anonymous_reads?
  validates_presence_of :bind_password, if: :allow_anonymous_reads?

  # Returns encryption method as symbol for Net::LDAP
  # Encryption options: plain (no encryption), simple_tls (LDAPS), start_tls (STARTTLS)
  def encryption_method
    return nil if plain?

    encryption.to_sym
  end

  def requires_auth?
    bind_dn.present? && bind_password.present?
  end
end
