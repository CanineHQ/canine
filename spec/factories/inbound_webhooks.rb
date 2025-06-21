# == Schema Information
#
# Table name: inbound_webhooks
#
#  id         :bigint           not null, primary key
#  body       :text
#  status     :integer          default("pending")
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :inbound_webhook do
    body { { "event" => "test_event", "data" => { "id" => 123 } }.to_json }
    status { "pending" }

    trait :processing do
      status { "processing" }
    end

    trait :processed do
      status { "processed" }
    end

    trait :failed do
      status { "failed" }
    end
  end
end
