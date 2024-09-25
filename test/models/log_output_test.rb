# == Schema Information
#
# Table name: log_outputs
#
#  id            :bigint           not null, primary key
#  loggable_type :string           not null
#  output        :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  loggable_id   :bigint           not null
#
require "test_helper"

class LogOutputTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
