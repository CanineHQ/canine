# == Schema Information
#
# Table name: builds
#
#  id             :bigint           not null, primary key
#  commit_message :string
#  commit_sha     :string           not null
#  git_sha        :string
#  repository_url :string
#  status         :integer          default("in_progress")
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
  include ActionView::RecordIdentifier
  include Loggable
  include Eventable

  belongs_to :project
  has_one :deployment, dependent: :destroy

  enum :status, {
    in_progress: 0,
    completed: 1,
    failed: 2,
    killed: 3
  }

  after_update_commit do
    broadcast_build
  end

  def broadcast_build
    if events.last
      broadcast_replace_later_to [ project, :events ], target: dom_id(self, :index), partial: "projects/deployments/event_build_row", locals: { project:, event: events.last }
    end
  end
end
