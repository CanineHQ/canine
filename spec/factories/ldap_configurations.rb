FactoryBot.define do
  factory :ldap_configuration do
    host { "MyString" }
    port { 1 }
    encryption { "MyString" }
    base_dn { "MyString" }
    bind_dn { "MyString" }
    bind_password { "MyString" }
    uid_attribute { "MyString" }
    email_attribute { "MyString" }
    name_attribute { "MyString" }
    filter { "MyString" }
  end
end
