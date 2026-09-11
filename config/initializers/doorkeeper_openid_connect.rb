# frozen_string_literal: true

Doorkeeper::OpenidConnect.configure do
  issuer do |_resource_owner, _application, request|
    request&.base_url || Rails.application.credentials.dig(:app, :host) || "https://canine.sh"
  end

  signing_key Rails.application.credentials.dig(:oidc, :signing_key) || OpenSSL::PKey::RSA.generate(2048).to_pem

  subject_types_supported [ :public ]

  resource_owner_from_access_token do |access_token|
    User.find_by(id: access_token.resource_owner_id)
  end

  auth_time_from_resource_owner do |resource_owner|
    resource_owner.current_sign_in_at || resource_owner.created_at
  end

  reauthenticate_resource_owner do |resource_owner, return_to|
    store_location_for resource_owner, return_to
    sign_out resource_owner
    redirect_to new_user_session_url
  end

  subject do |resource_owner, _application|
    resource_owner.id
  end

  expiration 3600

  claims do
    normal_claim :email, scope: :openid do |resource_owner|
      resource_owner.email
    end

    normal_claim :name, scope: :profile, response: %i[id_token user_info] do |resource_owner|
      resource_owner.name.to_s
    end

    normal_claim :preferred_username, scope: :profile do |resource_owner|
      resource_owner.email
    end
  end
end
