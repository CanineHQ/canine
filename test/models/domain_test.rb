# == Schema Information
#
# Table name: domains
#
#  id                 :bigint           not null, primary key
#  domain_name        :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  project_service_id :bigint           not null
#
# Indexes
#
#  index_domains_on_project_service_id  (project_service_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_service_id => project_services.id)
#
require "test_helper"

class DomainTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
