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
FactoryBot.define do
  factory :preview_project do
    project { nil }
    base_project { nil }
    external_id { "MyString" }
    clean_up_command { "MyText" }
  end
end
