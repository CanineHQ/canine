# == Schema Information
#
# Table name: saml_configurations
#
#  id                     :bigint           not null, primary key
#  authn_requests_signed  :boolean          default(FALSE)
#  email_attribute        :string           default("email")
#  groups_attribute       :string
#  idp_cert               :text             not null
#  idp_slo_service_url    :string
#  idp_sso_service_url    :string           not null
#  name_attribute         :string           default("name")
#  name_identifier_format :string           default("urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress")
#  uid_attribute          :string           default("email")
#  want_assertions_signed :boolean          default(TRUE)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  idp_entity_id          :string           not null
#  sp_entity_id           :string
#
FactoryBot.define do
  factory :saml_configuration do
    idp_entity_id { "https://idp.example.com/saml/metadata" }
    idp_sso_service_url { "https://idp.example.com/saml/sso" }
    idp_cert { <<~CERT }
-----BEGIN CERTIFICATE-----
MIICpDCCAYwCCQDU+pQ4P2U9MzANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls
b2NhbGhvc3QwHhcNMjQwMTAxMDAwMDAwWhcNMjUwMTAxMDAwMDAwWjAUMRIwEAYD
VQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC5
T8hTQ2zBGJ5dXKMJx5LZmJ/5E5mzk3nOqJzME8Xt+x5f6Y7S1G8F7cQrV6KxW8Vw
7J5LzF8v9D5F9VLvH7Lk7p7D5Y7h7C7n7L5k5P5B5A5E5I5O5U5Y5a5e5i5o5u5
y5c5g5k5o5s5w5B5F5J5N5R5V5Z5d5h5l5p5t5x5C5G5K5O5S5W5b5f5j5n5
r5v5z5D5H5L5P5T5X5c5g5k5o5s5w50DAQAB4y5C5G5K5O5S5W5b5f5j5n5r5
v5z5D5H5L5P5T5X5c5g5k5o5s5w5AgMBAAEwDQYJKoZIhvcNAQELBQADggEBAFWm
PZHcjJ8vJxqsM4k5m9T5t5x5C5G5K5O5S5W5b5f5j5n5r5v5z5D5H5L5P5T5X5
-----END CERTIFICATE-----
    CERT
    idp_slo_service_url { nil }
    name_identifier_format { "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress" }
    uid_attribute { "email" }
    email_attribute { "email" }
    name_attribute { "name" }
    groups_attribute { nil }
    sp_entity_id { nil }
    authn_requests_signed { false }
    want_assertions_signed { true }
  end
end
