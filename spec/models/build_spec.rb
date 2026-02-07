# frozen_string_literal: true

# == Schema Information
#
# Table name: builds
#
#  id             :bigint           not null, primary key
#  commit_message :string
#  commit_sha     :string           not null
#  digest         :string
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
require 'rails_helper'

RSpec.describe Build do
  let(:valid_digest) { "sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4" }

  describe "digest validation" do
    it "requires digest when completed and project is git-based" do
      build = create(:build, status: :in_progress)
      expect(build.project.git?).to be true

      build.status = :completed
      expect(build).not_to be_valid
      expect(build.errors[:digest]).to include("can't be blank")

      build.digest = valid_digest
      expect(build).to be_valid
    end

    it "validates digest format is a valid SHA256 string" do
      build = create(:build, status: :in_progress)

      build.digest = "sha256:abc123"
      expect(build).not_to be_valid
      expect(build.errors[:digest]).to include("must be a valid SHA256 digest")

      build.digest = "md5:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4"
      expect(build).not_to be_valid

      build.digest = "sha256:A3ED95CAEB02FFE68CDD9FD84406680AE93D633CB16422D00E8A7C22955B46D4"
      expect(build).not_to be_valid

      build.digest = valid_digest
      expect(build).to be_valid
    end

    it "does not require digest for non-completed statuses on git projects" do
      build = create(:build, status: :in_progress)
      expect(build).to be_valid

      build.status = :failed
      expect(build).to be_valid

      build.status = :killed
      expect(build).to be_valid
    end

    it "does not require digest for container registry projects" do
      project = create(:project, :container_registry)
      build = create(:build, project: project, status: :in_progress)
      expect(build.project.git?).to be false

      build.status = :completed
      expect(build).to be_valid
    end
  end
end
