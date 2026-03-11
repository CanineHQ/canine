# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::DeployProjectFork do
  it 'creates a fork from a pull request' do
    project = create(:project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)

    mock_pr = OpenStruct.new(
      id: 'pr-ext-id', number: 42, title: 'Add new feature',
      branch: 'feature-branch', url: 'https://github.com/org/repo/pull/42', user: 'developer'
    )
    allow(Git::Client).to receive(:from_project).and_return(double(pull_request: mock_pr))

    fork_project = create(:project, name: "#{project.name}-42", cluster: project.cluster)
    allow(ProjectForks::Create).to receive(:call).and_return(double(success?: true, project: fork_project))
    allow(Projects::VisibleToUser).to receive(:execute).and_return(double(projects: Project.where(id: project.id)))

    response = described_class.call(project_id: project.id, pr_number: 42, server_context: { user_id: user.id })

    expect(response.content.first[:text]).to include('Fork created')
    expect(response.content.first[:text]).to include('PR #42')
    expect(ProjectForks::Create).to have_received(:call).with(parent_project: project, pull_request: mock_pr)
  end

  it 'redeploys an existing fork' do
    project = create(:project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)

    fork_project = create(:project, name: "#{project.name}-42", cluster: project.cluster)
    create(:project_fork, parent_project: project, child_project: fork_project, number: 42, external_id: 'ext-42')

    mock_pr = OpenStruct.new(id: 'ext-42', number: 42, title: 'Existing PR', branch: 'feature', url: 'url', user: 'dev')
    allow(Git::Client).to receive(:from_project).and_return(double(pull_request: mock_pr))
    allow(Git::Client).to receive(:from_project).with(fork_project).and_return(
      double(commits: [ Git::Common::Commit.new(
        sha: "def456", message: "update", author_name: "Test", author_email: "t@t.com",
        authored_at: Time.current, committer_name: "Test", committer_email: "t@t.com",
        committed_at: Time.current, url: "http://example.com"
      ) ])
    )
    allow(Projects::BuildJob).to receive(:perform_later)
    allow(Projects::VisibleToUser).to receive(:execute).and_return(double(projects: Project.where(id: project.id)))

    response = described_class.call(project_id: project.id, pr_number: 42, server_context: { user_id: user.id })

    expect(response.content.first[:text]).to include('already exists')
    expect(response.content.first[:text]).to include('Redeployment started')
  end
end
