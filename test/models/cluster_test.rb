# == Schema Information
#
# Table name: clusters
#
#  id         :bigint           not null, primary key
#  kubeconfig :jsonb            not null
#  name       :string           not null
#  status     :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_clusters_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class ClusterTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
