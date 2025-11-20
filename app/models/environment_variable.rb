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
  validates :value, presence: true,
                   format: {
                    without: /[`\\|><;]/,
                    message: "cannot contain special characters that might enable command injection"
                   }

  before_validation :strip_whitespace

  def base64_encoded_value
    return nil unless value.present?
    Base64.strict_encode64(value)
  end

  private

  def strip_whitespace
    self.name = name.strip.upcase if name.present?
    self.value = value.strip if value.present?
  end
end
