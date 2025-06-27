# == Schema Information
#
# Table name: preview_projects
#
#  id               :bigint           not null, primary key
#  clean_up_command :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  external_id      :string
#  project_id       :bigint           not null
#
# Indexes
#
#  index_preview_projects_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
require 'rails_helper'

RSpec.describe PreviewProject, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
