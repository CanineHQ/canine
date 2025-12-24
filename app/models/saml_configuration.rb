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
class SAMLConfiguration < ApplicationRecord
  self.table_name = "saml_configurations"

  has_one :sso_provider, as: :configuration, dependent: :destroy
  has_one :account, through: :sso_provider

  validates :idp_entity_id, presence: true
  validates :idp_sso_service_url, presence: true
  validates :idp_cert, presence: true

  def settings_for(account)
    OneLogin::RubySaml::Settings.new.tap do |settings|
      settings.idp_entity_id = idp_entity_id
      settings.idp_sso_service_url = idp_sso_service_url
      settings.idp_cert = idp_cert
      settings.idp_slo_service_url = idp_slo_service_url if idp_slo_service_url.present?
      settings.name_identifier_format = name_identifier_format
      settings.sp_entity_id = sp_entity_id.presence || default_sp_entity_id(account)
      settings.assertion_consumer_service_url = Rails.application.routes.url_helpers.saml_callback_url(slug: account.slug)
      settings.idp_sso_service_binding = 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect'
      settings.security[:authn_requests_signed] = authn_requests_signed
      settings.security[:want_assertions_signed] = false
    end
  end

  private

  def default_sp_entity_id(account)
    Rails.application.routes.url_helpers.saml_metadata_url(slug: account.slug)
  end
end
