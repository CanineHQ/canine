# == Schema Information
#
# Table name: environment_variables
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
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

  validates :name, presence: true, uniqueness: { scope: :project_id }
  validates :value, presence: true

  before_save :strip_whitespace

  private

  def strip_whitespace
    self.name = name.strip.upcase
    self.value = value.strip
  end
end
