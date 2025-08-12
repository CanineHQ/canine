require "rails_helper"

RSpec.describe CleanupClosedPrProjectsJob, type: :job do
  let(:parent_project) { create(:project) }
  let(:child_project) { create(:project) }
  let(:project_fork) { create(:project_fork, parent_project: parent_project, child_project: child_project, number: "123") }
  let(:git_client) { instance_double(Git::Github::Client) }

  before do
    allow(Git::Client).to receive(:from_project).with(parent_project).and_return(git_client)
  end

  describe "#perform" do
    context "when PR is closed" do
      before do
        allow(git_client).to receive(:pull_request_status).with(123).and_return('closed')
      end

      it "destroys the child project" do
        project_fork
        expect { described_class.new.perform }.to change { Project.count }.by(-1)
        expect(Project.exists?(child_project.id)).to be false
      end
    end

    context "when PR is merged" do
      before do
        allow(git_client).to receive(:pull_request_status).with(123).and_return('merged')
      end

      it "destroys the child project" do
        project_fork
        expect { described_class.new.perform }.to change { Project.count }.by(-1)
        expect(Project.exists?(child_project.id)).to be false
      end
    end

    context "when PR is not found" do
      before do
        allow(git_client).to receive(:pull_request_status).with(123).and_return('not_found')
      end

      it "destroys the child project" do
        project_fork
        expect { described_class.new.perform }.to change { Project.count }.by(-1)
        expect(Project.exists?(child_project.id)).to be false
      end
    end

    context "when PR is open" do
      before do
        allow(git_client).to receive(:pull_request_status).with(123).and_return('open')
      end

      it "does not destroy the child project" do
        project_fork
        expect { described_class.new.perform }.not_to change { Project.count }
        expect(Project.exists?(child_project.id)).to be true
      end
    end

    context "when there's an error checking PR status" do
      before do
        allow(git_client).to receive(:pull_request_status).and_raise(StandardError, "API error")
      end

      it "logs the error and continues" do
        project_fork
        expect(Rails.logger).to receive(:error).with(/Error checking PR status/)
        expect { described_class.new.perform }.not_to change { Project.count }
      end
    end

    context "with multiple project forks" do
      let(:child_project2) { create(:project) }
      let(:project_fork2) { create(:project_fork, parent_project: parent_project, child_project: child_project2, number: "124") }

      before do
        allow(git_client).to receive(:pull_request_status).with(123).and_return('closed')
        allow(git_client).to receive(:pull_request_status).with(124).and_return('open')
      end

      it "only destroys projects with closed PRs" do
        project_fork
        project_fork2
        expect { described_class.new.perform }.to change { Project.count }.by(-1)
        expect(Project.exists?(child_project.id)).to be false
        expect(Project.exists?(child_project2.id)).to be true
      end
    end
  end
end
