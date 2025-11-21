# == Schema Information
#
# Table name: ldap_configurations
#
#  id               :bigint           not null, primary key
#  base_dn          :string           not null
#  bind_dn          :string
#  bind_password    :string
#  email_attribute  :string           default("mail")
#  encryption       :string           default("plain")
#  filter           :string
#  host             :string           not null
#  name_attribute   :string           default("cn")
#  port             :integer          default(389), not null
#  uid_attribute    :string           default("uid"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
class LdapConfiguration < ApplicationRecord
  has_one :sso_provider, as: :configuration, dependent: :destroy

  validates :host, presence: true
  validates :port, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :base_dn, presence: true
  validates :uid_attribute, presence: true
  validates :encryption, inclusion: { in: %w[plain simple_tls start_tls] }

  # Encryption options: plain (no encryption), simple_tls (LDAPS), start_tls (STARTTLS)
  def encryption_method
    case encryption
    when "simple_tls"
      :simple_tls
    when "start_tls"
      :start_tls
    else
      nil
    end
  end

  def requires_auth?
    bind_dn.present? && bind_password.present?
  end
end
