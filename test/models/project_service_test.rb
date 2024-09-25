# == Schema Information
#
# Table name: project_services
#
#  id           :bigint           not null, primary key
#  command      :string           not null
#  name         :string           not null
#  service_type :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  project_id   :bigint           not null
#
# Indexes
#
#  index_project_services_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
require "test_helper"

class ProjectServiceTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
