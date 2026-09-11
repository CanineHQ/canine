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
#  internal                :boolean          default(FALSE)
#  last_health_checked_at  :datetime
#  name                    :string           not null
#  pod_yaml                :jsonb
#  replicas                :integer          default(1)
#  service_type            :integer          not null
#  status                  :integer          default("pending")
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  project_id              :bigint           not null
#
# Indexes
#
#  index_services_on_project_id_and_name  (project_id,name) UNIQUE
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
  scope :running, -> { where(status: [ :healthy, :unhealthy, :updated ]) }

  has_one :cron_schedule, dependent: :destroy
  has_one :resource_constraint, dependent: :destroy
  has_one :oauth_application, class_name: "Doorkeeper::Application", dependent: :destroy

  validates :cron_schedule, presence: true, if: :cron_job?
  validates :command, presence: true, if: :cron_job?
  has_many :domains, dependent: :destroy
  validates :name, presence: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase, numbers, and hyphens only" },
                   uniqueness: { scope: :project_id }

  accepts_nested_attributes_for :domains, allow_destroy: true

  after_save :manage_oauth_application, if: :saved_change_to_internal?

  def internal_url
    # Kubernetes internal URL
    K8::Stateless::Service.new(self).internal_url
  end

  def auto_subdomain
    "#{name}-#{project.namespace}"
  end

  def auto_domain
    return nil unless allow_public_networking?

    "#{auto_subdomain}.#{Dns::Client.default.domain}"
  end

  def friendly_status
    if !web_service? && healthy?
      "deployed"
    else
      status.humanize
    end
  end

  def requires_auth?
    internal? || project.internal?
  end

  def effective_oauth_application
    oauth_application || project.oauth_application
  end

  def auth_proxy_cookie_secret
    effective_oauth_application&.secret&.first(32)
  end

  def self.permitted_params(params)
    permitted = params.require(:service).permit(
      :service_type,
      :command,
      :name,
      :container_port,
      :healthcheck_url,
      :replicas,
      :description,
      :allow_public_networking,
      :internal,
      :pod_yaml
    )

    # Convert YAML text to JSON if pod_yaml is a string
    if permitted[:pod_yaml].present? && permitted[:pod_yaml].is_a?(String)
      begin
        permitted[:pod_yaml] = YAML.safe_load(permitted[:pod_yaml])
      rescue Psych::SyntaxError => e
        # If YAML parsing fails, keep the original value so validation can catch it
        Rails.logger.error("Failed to parse pod_yaml: #{e.message}")
      end
    end

    permitted
  end

  private

  def manage_oauth_application
    if internal?
      return if oauth_application.present?

      redirect_uri = if auto_domain.present?
        "https://#{auto_domain}/oauth2/callback"
      else
        "https://placeholder.canine.sh/oauth2/callback"
      end

      create_oauth_application!(
        name: "Auth Proxy: #{name} (#{project.name})",
        redirect_uri: redirect_uri,
        scopes: "openid profile",
        confidential: true
      )
    else
      oauth_application&.destroy
    end
  end
end
