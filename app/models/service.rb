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
class Service < ApplicationRecord
  belongs_to :project
  enum :service_type, {
    web_service: 0,
    background_service: 1,
    cron_job: 2
  }

  enum :status, {
    pending: 0,
    healthy: 1,
    unhealthy: 2,
    updated: 3
  }

  has_one :cron_schedule, dependent: :destroy
  validates :cron_schedule, presence: true, if: :cron_job?
  validates :command, presence: true, if: :cron_job?
  has_many :domains, dependent: :destroy
  validates :name, presence: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase, numbers, and hyphens only" },
                   uniqueness: { scope: :project_id }

  accepts_nested_attributes_for :domains, allow_destroy: true

  def internal_url
    # Kubernetes internal URL
    K8::Stateless::Service.new(self).internal_url
  end

  def friendly_status
    if !web_service? && healthy?
      "deployed"
    else
      status.humanize
    end
  end

  def self.permitted_params(params)
    params.require(:service).permit(
      :service_type,
      :command,
      :name,
      :container_port,
      :healthcheck_url,
      :replicas,
      :description,
      :allow_public_networking,
    )
  end
end
