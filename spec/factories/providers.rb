# == Schema Information
#
# Table name: providers
#
#  id                  :bigint           not null, primary key
#  access_token        :string
#  access_token_secret :string
#  auth                :text
#  expires_at          :datetime
#  last_used_at        :datetime
#  provider            :string
#  refresh_token       :string
#  registry_url        :string
#  uid                 :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  user_id             :bigint           not null
#
# Indexes
#
#  index_providers_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :provider do
    user
    sequence(:access_token) { |n| "sample_access_token_#{n}" }
    auth { { "info" => { "nickname" => "test_user" } }.to_json }
    expires_at { nil }
    last_used_at { nil }
    provider { "github" }
    uid { "sample_uid" }
    trait :container_registry do
      provider { Provider::CUSTOM_REGISTRY_PROVIDER }
      auth { { "info" => { "username" => "test_user" } }.to_json }
      registry_url { "docker.io" }
    end

    trait :github do
      provider { Provider::GITHUB_PROVIDER }
      auth { { "info" => { "nickname" => "test_user" } }.to_json }
    end

    trait :gitlab do
      provider { Provider::GITLAB_PROVIDER }
      auth { { "info" => { "nickname" => "test_user" } }.to_json }
    end
  end
end
