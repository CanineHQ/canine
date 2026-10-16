# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Error tracking MCP tools' do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:context) { { user_id: user.id } }
  let(:configuration) { project.create_error_tracking_configuration! }
  let!(:event) do
    ErrorTracking::IngestEvent.call(configuration, {
      'event_id' => SecureRandom.hex(16), 'environment' => 'production', 'tags' => { 'tier' => 'gold' },
      'exception' => { 'values' => [ {
        'type' => 'NoMethodError', 'value' => "undefined method 'name' for nil",
        'stacktrace' => { 'frames' => [
          { 'filename' => 'gems/rack.rb', 'function' => 'call', 'lineno' => 1, 'in_app' => false },
          { 'filename' => 'app/models/user.rb', 'function' => 'display', 'lineno' => 8, 'in_app' => true,
            'pre_context' => [ 'def display' ], 'context_line' => '  owner.name', 'post_context' => [ 'end' ] }
        ] }
      } ] }
    })
  end
  let(:issue) { event.issue }

  def text(response) = response.content.first[:text]

  before { create(:account_user, account: project.account, user: user) }

  it 'shows the DSN on the project resource, lists issues, shows the stack trace and resolves an issue' do
    resource = Resources::Router.call("canine://accounts/#{project.account.id}/projects/#{project.id}", context)
    dsn = JSON.parse(resource.first[:text])['error_tracking_dsn']
    expect(dsn).to eq("https://#{configuration.public_key}@canine.example.com/#{configuration.id}") # APP_HOST from .env.test

    issues = JSON.parse(text(Tools::ListErrorIssues.call(project_id: project.id, server_context: context)))['issues']
    expect(issues.map { |i| i['title'] }).to eq([ "NoMethodError: undefined method 'name' for nil" ])
    expect(issues.first["short_id"]).to eq("#{project.name.upcase}-1")

    detail = JSON.parse(text(Tools::GetErrorIssue.call(project_id: project.id, issue_id: issue.id, server_context: context)))
    frames = detail.dig('event', 'exceptions', 0, 'frames')
    expect(frames.map { |f| f['filename'] }).to eq([ 'app/models/user.rb' ])
    expect(frames.first['source']).to eq("7: def display\n8:   owner.name\n9: end")
    expect(detail.dig('event', 'tags')).to eq('tier' => 'gold')
    expect(detail.dig('summary', 'tags')).to include('environment' => { 'production' => 1 }, 'tier' => { 'gold' => 1 })
    expect(detail.dig('event', 'exceptions', 0, 'omitted_frames')).to eq(1)

    Tools::UpdateErrorIssue.call(project_id: project.id, issue_id: issue.id, status: 'resolved', server_context: context)
    expect(issue.reload).to be_resolved
    expect(Tools::ListErrorIssues.call(project_id: project.id, status: 'bogus', server_context: context).error?).to be true
  end

  it 'pages and searches issues' do
    ErrorTracking::IngestEvent.call(configuration, { 'event_id' => SecureRandom.hex(16), 'message' => 'Timeout talking to Stripe' })
    list = ->(**args) { JSON.parse(text(Tools::ListErrorIssues.call(project_id: project.id, server_context: context, **args))) }

    first_page = list.call(limit: 1)
    second_page = list.call(limit: 1, page: 2)
    expect(first_page.values_at('page', 'has_more')).to eq([ 1, true ])
    expect(second_page.values_at('page', 'has_more')).to eq([ 2, false ])
    expect((first_page['issues'] + second_page['issues']).map { |i| i['id'] }).to contain_exactly(issue.id, ErrorTracking::Issue.last.id)

    expect(list.call(query: 'stripe')['issues'].map { |i| i['title'] }).to eq([ 'Timeout talking to Stripe' ])
    expect(list.call(query: issue.short_id.downcase)['issues'].map { |i| i['id'] }).to eq([ issue.id ])
    expect(list.call(query: '100%')['issues']).to be_empty
  end

  it "does not expose another account's issues" do
    outsider = create(:user)
    create(:account_user, user: outsider)
    response = Tools::GetErrorIssue.call(project_id: project.id, issue_id: issue.id, server_context: { user_id: outsider.id })

    expect(response.error?).to be true
  end
end
