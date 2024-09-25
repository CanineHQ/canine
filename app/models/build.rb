# == Schema Information
#
# Table name: builds
#
#  id             :bigint           not null, primary key
#  commit_message :string
#  commit_sha     :string           not null
#  git_sha        :string
#  repository_url :string
#  status         :integer          default(0)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  project_id     :bigint           not null
#
# Indexes
#
#  index_builds_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
class Build < ApplicationRecord
  include Loggable
  belongs_to :project
  has_one :deployment, dependent: :destroy
  enum status: {
    in_progress: 0,
    completed: 1,
    failed: 2
  }
end
