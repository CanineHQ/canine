# == Schema Information
#
# Table name: api_tokens
#
#  id           :bigint           not null, primary key
#  access_token :string           not null
#  expires_at   :datetime
#  last_used_at :datetime
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_api_tokens_on_access_token  (access_token) UNIQUE
#  index_api_tokens_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :api_token do
    user
    name { "API Token" }
    expires_at { nil }
    last_used_at { nil }
  end
end
