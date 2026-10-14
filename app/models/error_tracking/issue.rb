# == Schema Information
#
# Table name: error_tracking_issues
#
#  id                              :bigint           not null, primary key
#  culprit                         :string
#  fingerprint                     :string           not null
#  first_seen_at                   :datetime         not null
#  last_seen_at                    :datetime         not null
#  level                           :string           default("error"), not null
#  platform                        :string
#  status                          :integer          default("unresolved"), not null
#  times_seen                      :integer          default(0), not null
#  title                           :string           not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  error_tracking_configuration_id :bigint           not null
#
# Indexes
#
#  idx_on_error_tracking_configuration_id_fingerprint_af48550853   (error_tracking_configuration_id,fingerprint) UNIQUE
#  idx_on_error_tracking_configuration_id_status_last__85f6cea452  (error_tracking_configuration_id,status,last_seen_at)
#
# Foreign Keys
#
#  fk_rails_...  (error_tracking_configuration_id => error_tracking_configurations.id) ON DELETE => cascade
#
module ErrorTracking
  class Issue < ApplicationRecord
    belongs_to :error_tracking_configuration
    has_many :events, dependent: :delete_all

    enum :status, { unresolved: 0, resolved: 1, ignored: 2 }

    LEVELS = %w[fatal error warning info debug].freeze

    def latest_event
      events.order(occurred_at: :desc).first
    end
  end
end
