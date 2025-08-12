# == Schema Information
#
# Table name: services
#
#  id                      :bigint           not null, primary key
#  allow_public_networking :boolean          default(FALSE)
#  command                 :string
#  container_port          :integer          default(3000)
#  description             :text
#  healthcheck_url         :string
#  last_health_checked_at  :datetime
#  name                    :string           not null
#  replicas                :integer          default(1)
#  service_type            :integer          not null
#  status                  :integer          default("pending")
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  project_id              :bigint           not null
#
# Indexes
#
#  index_services_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
FactoryBot.define do
  factory :service do
    project
    sequence(:name) { |n| "example-service-#{n}" }
    container_port { 3000 }
    status { :pending }
    service_type { :web_service }

    trait :cron_job do
      service_type { :cron_job }
      command { "rails runner 'puts \"Hello World\"'" }
      after(:build) do |service|
        service.cron_schedule ||= build(:cron_schedule, service: service)
      end
    end
  end
end
