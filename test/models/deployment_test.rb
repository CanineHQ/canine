# == Schema Information
#
# Table name: deployments
#
#  id         :bigint           not null, primary key
#  status     :integer          default(0), not null
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
require "test_helper"

class DeploymentTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
