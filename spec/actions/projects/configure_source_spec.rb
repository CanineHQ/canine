# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Projects::ConfigureSource do
  describe '.configure_from_public_image_url' do
    let(:project) { Project.new }

    def parse(url)
      params = ActionController::Parameters.new({ project: { public_image_url: url } })
      described_class.configure_from_public_image_url(project, params)
    end

    it 'parses image with tag' do
      parse('docker.io/library/nginx:latest')
      expect(project.repository_base_url).to eq('docker.io')
      expect(project.repository_url).to eq('library/nginx')
      expect(project.branch).to eq('latest')
      expect(project.provider_type).to eq(Provider::CUSTOM_REGISTRY_PROVIDER)
    end

    it 'parses image with version tag' do
      parse('ghcr.io/org/repo:v1.2.3')
      expect(project.repository_base_url).to eq('ghcr.io')
      expect(project.repository_url).to eq('org/repo')
      expect(project.branch).to eq('v1.2.3')
    end

    it 'defaults tag to latest when no tag provided' do
      parse('docker.stirlingpdf.com/stirlingtools/stirling-pdf')
      expect(project.repository_base_url).to eq('docker.stirlingpdf.com')
      expect(project.repository_url).to eq('stirlingtools/stirling-pdf')
      expect(project.branch).to eq('latest')
    end

    it 'handles port in registry URL with tag' do
      parse('localhost:5000/myrepo:v1')
      expect(project.repository_base_url).to eq('localhost:5000')
      expect(project.repository_url).to eq('myrepo')
      expect(project.branch).to eq('v1')
    end

    it 'handles port in registry URL without tag' do
      parse('localhost:5000/myrepo')
      expect(project.repository_base_url).to eq('localhost:5000')
      expect(project.repository_url).to eq('myrepo')
      expect(project.branch).to eq('latest')
    end

    it 'does nothing when public_image_url is blank' do
      project.repository_url = 'existing/repo'
      project.branch = 'main'
      parse('')
      expect(project.repository_url).to eq('existing/repo')
      expect(project.branch).to eq('main')
    end

    it 'parses simple docker hub image with tag' do
      parse('nginx:alpine')
      expect(project.repository_base_url).to eq('docker.io')
      expect(project.repository_url).to eq('nginx')
      expect(project.branch).to eq('alpine')
    end

    it 'parses docker hub owner/repo without registry host' do
      parse('library/nginx:latest')
      expect(project.repository_base_url).to eq('docker.io')
      expect(project.repository_url).to eq('library/nginx')
      expect(project.branch).to eq('latest')
    end
  end
end
