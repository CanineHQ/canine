# == Schema Information
#
# Table name: services
#
#  id                      :bigint           not null, primary key
#  allow_public_networking :boolean          default(FALSE)
#  command                 :string
#  container_port          :integer          default(3000)
#  healthcheck_url         :string
#  last_health_checked_at  :datetime
#  name                    :string           not null
#  service_type            :integer          not null
#  status                  :integer
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
class Service < ApplicationRecord
  belongs_to :project
  enum :service_type, {
    web_service: 0,
    background_service: 1,
    cron_job: 2
  }

  enum :status, {
    healthy: 0,
    unhealthy: 1
  }

  has_one :cron_schedule, dependent: :destroy
  validates :cron_schedule, presence: true, if: :cron_job?
  validates :command, presence: true, if: :cron_job?
  has_many :domains, dependent: :destroy
  validates :name, presence: true,
                   format: { with: /\A[a-z0-9_-]+\z/, message: "must be lowercase, numbers, hyphens, and underscores only" }

  accepts_nested_attributes_for :domains, allow_destroy: true
end
