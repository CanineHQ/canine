# == Schema Information
#
# Table name: inbound_webooks
#
#  id         :bigint           not null, primary key
#  body       :text
#  status     :integer          default("pending")
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class InboundWebookTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
