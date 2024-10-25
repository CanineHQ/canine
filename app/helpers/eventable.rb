module Eventable
  extend ActiveSupport::Concern

  included do
    attr_accessor :current_user
    has_many :events, as: :eventable, dependent: :destroy
    after_save :create_event
  end

  def create_event
    events.create!(
      user: current_user,
      event_action: id_changed? ? :create : :update,
      project:
    )
  end
end
