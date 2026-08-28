# == Schema Information
#
# Table name: accounts
#
#  id                     :bigint           not null, primary key
#  allow_mcp              :boolean          default(TRUE), not null
#  name                   :string           not null
#  plan                   :integer          default("free"), not null
#  slug                   :string           not null
#  subscription_status    :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  owner_id               :bigint
#  stripe_customer_id     :string
#  stripe_subscription_id :string
#
# Indexes
#
#  index_accounts_on_owner_id                (owner_id)
#  index_accounts_on_slug                    (slug) UNIQUE
#  index_accounts_on_stripe_customer_id      (stripe_customer_id) UNIQUE
#  index_accounts_on_stripe_subscription_id  (stripe_subscription_id) UNIQUE
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
      create(:account_user, account: account, user: account.owner, role: :owner)
    end

    trait :with_stack_manager do
      after(:create) do |account|
        create(:stack_manager, account:)
      end
    end
  end
end
