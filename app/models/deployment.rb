# == Schema Information
#
# Table name: deployments
#
#  id         :bigint           not null, primary key
#  status     :integer          default("in_progress"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  build_id   :bigint           not null
#
# Indexes
#
#  index_deployments_on_build_id  (build_id)
#
# Foreign Keys
#
#  fk_rails_...  (build_id => builds.id)
#
class Deployment < ApplicationRecord
  include Loggable
  belongs_to :build
  has_one :project, through: :build
  enum status: {
    in_progress: 0,
    completed: 1,
    failed: 2
  }
end
