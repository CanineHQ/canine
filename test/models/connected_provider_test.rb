# == Schema Information
#
# Table name: connected_providers
#
#  id                  :bigint           not null, primary key
#  access_token        :string
#  access_token_secret :string
#  auth                :text
#  expires_at          :datetime
#  owner_type          :string
#  provider            :string
#  refresh_token       :string
#  uid                 :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  owner_id            :bigint
#
# Indexes
#
#  index_connected_providers_on_owner  (owner_type,owner_id)
#
require "test_helper"

class ConnectedProviderTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
