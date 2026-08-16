# == Schema Information
#
# Table name: notifiers
#
#  id                 :bigint           not null, primary key
#  enabled            :boolean          default(TRUE), not null
#  name               :string           not null
#  notification_types :text             default(["\"build\"", "\"deployment\"", "\"health\""]), not null, is an Array
#  provider_type      :integer          default("slack"), not null
#  webhook_url        :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  project_id         :bigint           not null
#
# Indexes
#
#  index_notifiers_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
class Notifier < ApplicationRecord
  belongs_to :project

  enum :provider_type, { slack: 0, discord: 1, microsoft_teams: 2, google_chat: 3 }

  validates :name, presence: true
  validates :webhook_url, presence: true,
                          format: { with: URI::DEFAULT_PARSER.make_regexp(%w[https]), message: "must be a valid HTTPS URL" }
  validate :webhook_url_matches_provider

  NOTIFICATION_TYPES = %w[build deployment health].freeze

  scope :enabled, -> { where(enabled: true) }
  scope :for_type, ->(type) { where("? = ANY(notification_types)", type.to_s) }

  validates :notification_types, presence: true

  private

  def webhook_url_matches_provider
    return if webhook_url.blank?

    case provider_type
    when "slack"
      unless webhook_url.include?("hooks.slack.com")
        errors.add(:webhook_url, "must be a valid Slack webhook URL")
      end
    when "discord"
      unless webhook_url.include?("discord.com/api/webhooks") || webhook_url.include?("discordapp.com/api/webhooks")
        errors.add(:webhook_url, "must be a valid Discord webhook URL")
      end
    when "microsoft_teams"
      unless webhook_url.include?(".webhook.office.com") || webhook_url.include?("outlook.office.com/webhook")
        errors.add(:webhook_url, "must be a valid Microsoft Teams webhook URL")
      end
    when "google_chat"
      unless webhook_url.include?("chat.googleapis.com")
        errors.add(:webhook_url, "must be a valid Google Chat webhook URL")
      end
    end
  end
end
