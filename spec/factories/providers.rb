FactoryBot.define do
  factory :provider do
    user
    sequence(:access_token) { |n| "sample_access_token_#{n}" }
    auth { { "info" => { "nickname" => "test_user" } }.to_json }
    expires_at { nil }
    last_used_at { nil }
    provider { "github" }
    uid { "sample_uid" }
  end
end
