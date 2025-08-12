# == Schema Information
#
# Table name: events
#
#  id             :bigint           not null, primary key
#  event_action   :integer          not null
#  eventable_type :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  eventable_id   :bigint           not null
#  project_id     :bigint           not null
#  user_id        :bigint
#
# Indexes
#
#  index_events_on_eventable   (eventable_type,eventable_id)
#  index_events_on_project_id  (project_id)
#  index_events_on_user_id     (user_id)
#
class Event < ApplicationRecord
  belongs_to :eventable, polymorphic: true
  belongs_to :user, optional: true
  belongs_to :project
  enum :event_action, {
    create: 0,
    update: 1
  }, prefix: true

  after_create_commit do
    broadcast_prepend_to [ project, :events ], target: "events", partial: "projects/deployments/event_row", locals: { project:, event: self }
    broadcast_remove_to [ project, :events ], target: "no-events-message"
  end

  def external_link
    if project.github?
      "https://github.com/#{project.repository_url}/commit/#{eventable.commit_sha}"
    else
      "https://hub.docker.com/r/#{project.repository_url}/tags"
    end
  end
end
