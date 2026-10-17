# == Schema Information
#
# Table name: agent_provider_keys
#
#  id           :bigint           not null, primary key
#  api_key      :text             not null
#  last_used_at :datetime
#  name         :string
#  provider     :string           default("openrouter"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_agent_provider_keys_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class AgentProviderKey < ApplicationRecord
  PROVIDERS = { "openrouter" => "OpenRouter" }.freeze

  belongs_to :account

  validates :api_key, presence: true
  validates :provider, inclusion: { in: PROVIDERS.keys }

  def masked
    "#{api_key.first(6)}…#{api_key.last(4)}"
  end
end
