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
#  index_notifiers_on_project_id           (project_id)
#  index_notifiers_on_project_id_and_name  (project_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
class Notifier < ApplicationRecord
  belongs_to :project

  enum :provider_type, { slack: 0, discord: 1 }

  validates :name, presence: true,
                   uniqueness: { scope: :project_id },
                   format: { with: /\A[a-zA-Z0-9_-]+\z/, message: "can only contain letters, numbers, hyphens, and underscores" }
  validates :webhook_url, presence: true,
                          format: { with: URI::DEFAULT_PARSER.make_regexp(%w[https]), message: "must be a valid HTTPS URL" }
  validate :webhook_url_matches_provider

  scope :enabled, -> { where(enabled: true) }

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
    end
  end
end
