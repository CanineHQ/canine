# == Schema Information
#
# Table name: services
#
#  id             :bigint           not null, primary key
#  command        :string           not null
#  container_port :integer          default(3000)
#  name           :string           not null
#  service_type   :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  project_id     :bigint           not null
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
  has_one :cron_schedule
  validates :cron_schedule, presence: true, if: :cron_job?
  validates :command, presence: true, if: :cron_job?
  has_many :domains, dependent: :destroy
end
