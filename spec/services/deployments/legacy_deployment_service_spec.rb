require 'rails_helper'

RSpec.describe Deployments::LegacyDeploymentService do
  let(:project) { create(:project) }
  let(:build) { create(:build, project: project) }
  let(:deployment) { create(:deployment, build: build) }
  let(:user) { project.account.owner }
  let(:service_instance) { described_class.new(deployment, user) }
  let(:applied_yamls) { [] }

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
    allow_any_instance_of(K8::Kubectl).to receive(:apply_yaml) do |_instance, yaml|
      applied_yamls << yaml
    end
    allow_any_instance_of(K8::Kubectl).to receive(:call).and_return("items: []")
    allow(Providers::GenerateConfigJson).to receive(:execute).and_return(
      double(failure?: false, docker_config_json: '{}')
    )

    service_instance.deploy
  end

  def find_applied_resource(kind, name = nil)
    applied_yamls.find do |yaml_str|
      yaml = YAML.safe_load(yaml_str)
      matches_kind = yaml['kind'] == kind
      matches_name = name.nil? || yaml.dig('metadata', 'name') == name
      matches_kind && matches_name
    end
  end

  def parse_yaml(yaml_str)
    YAML.safe_load(yaml_str)
  end

  describe 'deployment status' do
    it 'marks deployment as completed' do
      expect(deployment.reload.status).to eq('completed')
    end

    it 'marks project as deployed' do
      expect(project.reload.status).to eq('deployed')
    end

    it 'marks services as healthy' do
      expect(web_service.reload.status).to eq('healthy')
      expect(worker_service.reload.status).to eq('healthy')
      expect(cron_service.reload.status).to eq('healthy')
    end
  end

  describe 'web service resources' do
    it 'applies a Deployment' do
      yaml_str = find_applied_resource('Deployment', 'web')
      expect(yaml_str).to be_present

      yaml = parse_yaml(yaml_str)
      expect(yaml.dig('spec', 'selector', 'matchLabels', 'app')).to eq('web')
    end

    it 'applies a Service' do
      yaml_str = find_applied_resource('Service', 'web-service')
      expect(yaml_str).to be_present

      yaml = parse_yaml(yaml_str)
      expect(yaml.dig('spec', 'selector', 'app')).to eq('web')
    end

    it 'applies an Ingress with domain' do
      yaml_str = find_applied_resource('Ingress', 'web-ingress')
      expect(yaml_str).to be_present

      yaml = parse_yaml(yaml_str)
      expect(yaml.dig('spec', 'rules', 0, 'host')).to eq('example.com')
    end
  end

  describe 'background worker resources' do
    it 'applies a Deployment' do
      yaml_str = find_applied_resource('Deployment', 'worker')
      expect(yaml_str).to be_present

      yaml = parse_yaml(yaml_str)
      expect(yaml.dig('spec', 'selector', 'matchLabels', 'app')).to eq('worker')
    end

    it 'does not apply a Service' do
      yaml_str = find_applied_resource('Service', 'worker-service')
      expect(yaml_str).to be_nil
    end
  end

  describe 'cron job resources' do
    it 'applies a CronJob with schedule' do
      yaml_str = find_applied_resource('CronJob', 'scheduler')
      expect(yaml_str).to be_present

      yaml = parse_yaml(yaml_str)
      expect(yaml.dig('spec', 'schedule')).to be_present
    end
  end

  describe 'shared resources' do
    it 'applies ConfigMap' do
      yaml_str = find_applied_resource('ConfigMap')
      expect(yaml_str).to be_present
    end

    it 'applies Secrets' do
      yaml_str = find_applied_resource('Secret')
      expect(yaml_str).to be_present
    end

    it 'applies Namespace when managed' do
      yaml_str = find_applied_resource('Namespace')
      expect(yaml_str).to be_present
    end
  end
end
