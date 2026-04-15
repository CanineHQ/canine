# == Schema Information
#
# Table name: dev_environment_forks
#
#  id                :bigint           not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  child_project_id  :bigint           not null
#  parent_project_id :bigint           not null
#
# Indexes
#
#  index_dev_environment_forks_on_child_project_id   (child_project_id) UNIQUE
#  index_dev_environment_forks_on_parent_project_id  (parent_project_id)
#
# Foreign Keys
#
#  fk_rails_...  (child_project_id => projects.id)
#  fk_rails_...  (parent_project_id => projects.id)
#
require 'rails_helper'

RSpec.describe DevEnvironmentFork, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
