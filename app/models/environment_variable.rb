# == Schema Information
#
# Table name: environment_variables
#
#  id           :bigint           not null, primary key
#  name         :string           not null
#  storage_type :integer          default("config"), not null
#  value        :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  project_id   :bigint           not null
#
# Indexes
#
#  index_environment_variables_on_project_id           (project_id)
#  index_environment_variables_on_project_id_and_name  (project_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
class EnvironmentVariable < ApplicationRecord
  include Eventable

  belongs_to :project

  enum :storage_type, { config: 0, secret: 1 }

  validates :name, presence: true,
                  uniqueness: { scope: :project_id },
                  format: {
                    with: /\A[A-Z0-9_]+\z/,
                    message: "can only contain uppercase letters, numbers, and underscores"
                  }
  validates :value, presence: true
  validate :value_does_not_contain_injection_characters

  before_validation :strip_whitespace

  def base64_encoded_value
    return nil unless value.present?
    Base64.strict_encode64(value)
  end

  private

  # Characters that could enable command injection in shell contexts
  # Allows newlines for multi-line values (certificates, keys, etc.)
  INJECTION_CHARACTERS = /[`|><;]/.freeze

  def value_does_not_contain_injection_characters
    return unless value.present?

    if value.match?(INJECTION_CHARACTERS)
      errors.add(:value, "cannot contain special characters that might enable command injection")
    end
  end

  def strip_whitespace
    self.name = name.strip.upcase if name.present?
    # Only strip leading/trailing whitespace, preserve internal newlines
    self.value = value.strip if value.present?
  end
end
