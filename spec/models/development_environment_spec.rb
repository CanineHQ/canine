# == Schema Information
#
# Table name: development_environments
#
#  id                :bigint           not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  child_project_id  :bigint           not null
#  parent_project_id :bigint           not null
#
# Indexes
#
#  index_development_environments_on_child_project_id   (child_project_id) UNIQUE
#  index_development_environments_on_parent_project_id  (parent_project_id)
#
# Foreign Keys
#
#  fk_rails_...  (child_project_id => projects.id)
#  fk_rails_...  (parent_project_id => projects.id)
#
require 'rails_helper'

RSpec.describe DevelopmentEnvironments::Destroy do
  it "disconnects child dev environments without deleting them when parent is destroyed" do
    parent_project = create(:project)
    forks = create_list(:development_environment, 3, parent_project: parent_project)
    child_ids = forks.map(&:child_project_id)

    DevelopmentEnvironments::Destroy.execute(project: parent_project)

    expect(DevelopmentEnvironment.where(parent_project_id: parent_project.id).count).to eq 0
    child_ids.each { |id| expect(Project.exists?(id)).to be true }
  end

  it "disconnects from parent without deleting parent when child is destroyed" do
    fork = create(:development_environment)
    parent_project = fork.parent_project

    DevelopmentEnvironments::Destroy.execute(project: fork.child_project)

    expect(DevelopmentEnvironment.exists?(fork.id)).to be false
    expect(Project.exists?(parent_project.id)).to be true
  end
end
