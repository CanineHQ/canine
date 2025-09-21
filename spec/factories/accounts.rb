# == Schema Information
#
# Table name: accounts
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  owner_id   :bigint
#
# Indexes
#
#  index_accounts_on_owner_id  (owner_id)
#  index_accounts_on_slug      (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (owner_id => users.id)
#
FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "test-account-#{n}" }
    association :owner, factory: :user

    after(:create) do |account|
      create(:account_user, account: account, user: account.owner)
    end

    trait :with_stack_manager do
      after(:create) do |account|
        create(:stack_manager, account:)
      end
    end
  end
end
