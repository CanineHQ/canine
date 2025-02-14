# == Schema Information
#
# Table name: builds
#
#  id             :bigint           not null, primary key
#  commit_message :string
#  commit_sha     :string           not null
#  git_sha        :string
#  repository_url :string
#  status         :integer          default("in_progress")
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  project_id     :bigint           not null
#
# Indexes
#
#  index_builds_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
FactoryBot.define do
  factory :build do
    project

    commit_message { "Initial commit" }
    commit_sha { "abc123" }
    git_sha { "def456" }
    repository_url { "https://github.com/example/repo.git" }
    status { :in_progress }
  end
end
