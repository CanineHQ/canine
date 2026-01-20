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
require 'rails_helper'

RSpec.describe Notifier, type: :model do
  describe "validations" do
    it "is valid with valid Slack attributes and validates webhook URL matches provider" do
      notifier = build(:notifier)
      expect(notifier).to be_valid

      # Slack notifier with Discord URL should be invalid
      notifier.webhook_url = "https://discord.com/api/webhooks/123/abc"
      expect(notifier).not_to be_valid
      expect(notifier.errors[:webhook_url]).to include("must be a valid Slack webhook URL")
    end

    it "is valid with valid Discord attributes and validates webhook URL matches provider" do
      notifier = build(:notifier, :discord)
      expect(notifier).to be_valid

      # Discord notifier with Slack URL should be invalid
      notifier.webhook_url = "https://hooks.slack.com/services/T/B/X"
      expect(notifier).not_to be_valid
      expect(notifier.errors[:webhook_url]).to include("must be a valid Discord webhook URL")
    end

    it "requires HTTPS webhook URLs" do
      notifier = build(:notifier, webhook_url: "http://hooks.slack.com/services/T/B/X")
      expect(notifier).not_to be_valid
      expect(notifier.errors[:webhook_url]).to include("must be a valid HTTPS URL")
    end
  end

  describe "scopes" do
    it "filters by enabled status" do
      project = create(:project)
      enabled = create(:notifier, project: project, enabled: true)
      disabled = create(:notifier, :disabled, project: project)

      expect(project.notifiers.enabled).to include(enabled)
      expect(project.notifiers.enabled).not_to include(disabled)
    end
  end
end
