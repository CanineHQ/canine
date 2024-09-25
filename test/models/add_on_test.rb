# == Schema Information
#
# Table name: add_ons
#
#  id         :bigint           not null, primary key
#  chart_type :string           not null
#  metadata   :jsonb
#  name       :string           not null
#  status     :integer          default("installing"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :bigint           not null
#
# Indexes
#
#  index_add_ons_on_cluster_id           (cluster_id)
#  index_add_ons_on_cluster_id_and_name  (cluster_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#
require "test_helper"

class AddOnTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
