# == Schema Information
#
# Table name: notifiers
#
#  id            :bigint           not null, primary key
#  enabled       :boolean          default(TRUE), not null
#  name          :string           not null
#  provider_type :integer          default("slack"), not null
#  webhook_url   :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  project_id    :bigint           not null
#
# Indexes
#
#  index_notifiers_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
FactoryBot.define do
  factory :notifier do
    project
    sequence(:name) { |n| "notifier-#{n}" }
    provider_type { :slack }
    webhook_url { "https://hooks.slack.com/services/TEST/WEBHOOK/URL" }
    enabled { true }

    trait :discord do
      provider_type { :discord }
      webhook_url { "https://discord.com/api/webhooks/123456/abcdef" }
    end

    trait :microsoft_teams do
      provider_type { :microsoft_teams }
      webhook_url { "https://outlook.office.com/webhook/test" }
    end

    trait :google_chat do
      provider_type { :google_chat }
      webhook_url { "https://chat.googleapis.com/v1/spaces/test/messages" }
    end

    trait :disabled do
      enabled { false }
    end
  end
end
