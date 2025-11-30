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
#  reader_dn             :string
#  reader_password       :string
#  uid_attribute         :string           default("uid"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
FactoryBot.define do
  factory :ldap_configuration do
    host { "ldap.example.com" }
    port { 389 }
    encryption { "plain" }
    base_dn { "ou=users,dc=example,dc=com" }
    bind_dn { "cn=admin,dc=example,dc=com" }
    bind_password { "password" }
    uid_attribute { "uid" }
    email_attribute { "mail" }
    name_attribute { "cn" }
    filter { nil }
  end
end
