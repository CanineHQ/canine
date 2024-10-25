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
  belongs_to :user
  belongs_to :project
  enum event_action: {
    create: 0,
    update: 1
  }, _prefix: true
end
