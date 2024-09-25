# == Schema Information
#
# Table name: project_add_ons
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  add_on_id  :bigint           not null
#  project_id :bigint           not null
#
# Indexes
#
#  index_project_add_ons_on_add_on_id   (add_on_id)
#  index_project_add_ons_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (add_on_id => add_ons.id)
#  fk_rails_...  (project_id => projects.id)
#
class ProjectAddOn < ApplicationRecord
end
