require 'rails_helper'

class MockChartBuilder
  attr_reader :resources

  def initialize
    @resources = []
  end

  def connect(connection)
    self
  end

  def register_before_install(&block)
  end

  def <<(resource)
    @resources << resource
  end

  def install_chart(namespace, atomic: true, wait: true)
  end
end

RSpec.describe Deployments::HelmDeploymentService do
  let(:project) { create(:project) }
  let(:build) { create(:build, project: project) }
  let(:deployment) { create(:deployment, build: build) }
  let(:user) { project.account.owner }
  let(:service_instance) { described_class.new(deployment, user) }
  let(:mock_chart_builder) { MockChartBuilder.new }

  let!(:web_service) do
    create(:service,
      project: project,
      name: 'web',
      service_type: :web_service,
      allow_public_networking: true
    ).tap { |s| create(:domain, service: s, domain_name: 'example.com') }
  end

  let!(:worker_service) do
    create(:service, :background_service,
      project: project,
      name: 'worker'
    )
  end

  let!(:cron_service) do
    create(:service, :cron_job,
      project: project,
      name: 'scheduler'
    )
  end

  before do
    allow(K8::Helm::ChartBuilder).to receive(:new).and_return(mock_chart_builder)
    allow_any_instance_of(K8::Kubectl).to receive(:apply_yaml)
    allow_any_instance_of(K8::Kubectl).to receive(:call)
    allow(Providers::GenerateConfigJson).to receive(:execute).and_return(
      double(failure?: false, docker_config_json: '{}')
    )

    service_instance.deploy
  end

  def find_resource(kind, name = nil)
    mock_chart_builder.resources.find do |r|
      yaml = YAML.safe_load(r.to_yaml)
      matches_kind = yaml['kind'] == kind
      matches_name = name.nil? || yaml.dig('metadata', 'name') == name
      matches_kind && matches_name
    end
  end

  def parse_yaml(resource)
    YAML.safe_load(resource.to_yaml)
  end

  describe 'web service resources' do
    it 'generates a Deployment with correct selector' do
      resource = find_resource('Deployment', 'web')
      expect(resource).to be_present

      yaml = parse_yaml(resource)
      expect(yaml.dig('spec', 'selector', 'matchLabels', 'app')).to eq('web')
    end

    it 'generates a Service' do
      resource = find_resource('Service', 'web-service')
      expect(resource).to be_present

      yaml = parse_yaml(resource)
      expect(yaml.dig('spec', 'selector', 'app')).to eq('web')
    end

    it 'generates an Ingress with domain' do
      resource = find_resource('Ingress', 'web-ingress')
      expect(resource).to be_present

      yaml = parse_yaml(resource)
      expect(yaml.dig('spec', 'rules', 0, 'host')).to eq('example.com')
    end
  end

  describe 'background worker resources' do
    it 'generates a Deployment' do
      resource = find_resource('Deployment', 'worker')
      expect(resource).to be_present

      yaml = parse_yaml(resource)
      expect(yaml.dig('spec', 'selector', 'matchLabels', 'app')).to eq('worker')
    end

    it 'does not generate a Service' do
      resource = find_resource('Service', 'worker')
      expect(resource).to be_nil
    end
  end

  describe 'cron job resources' do
    it 'generates a CronJob with schedule' do
      resource = find_resource('CronJob', 'scheduler')
      expect(resource).to be_present

      yaml = parse_yaml(resource)
      expect(yaml.dig('spec', 'schedule')).to be_present
    end
  end

  describe 'shared resources' do
    it 'generates ConfigMap' do
      resource = find_resource('ConfigMap')
      expect(resource).to be_present
    end

    it 'generates registry Secret' do
      resource = find_resource('Secret')
      expect(resource).to be_present
    end
  end
end
