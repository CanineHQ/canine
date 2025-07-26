require 'rails_helper'

RSpec.describe K8::Stateless::CronJob do
  let(:project) { create(:project) }
  let(:service) { create(:service, :cron_job, project: project) }
  let(:cron_job) { described_class.new(service) }

  describe '#run_history' do
    let(:job_response) do
      {
        items: [
          {
            metadata: {
              name: 'test-job-1',
              ownerReferences: [
                { kind: 'CronJob', name: service.name }
              ]
            },
            status: {
              startTime: '2024-01-01T10:00:00Z',
              completionTime: '2024-01-01T10:05:00Z',
              succeeded: 1,
              failed: 0,
              active: 0
            }
          },
          {
            metadata: {
              name: 'test-job-2',
              ownerReferences: [
                { kind: 'CronJob', name: service.name }
              ]
            },
            status: {
              startTime: '2024-01-01T09:00:00Z',
              completionTime: '2024-01-01T09:10:00Z',
              succeeded: 0,
              failed: 1,
              active: 0
            }
          },
          {
            metadata: {
              name: 'test-job-3',
              ownerReferences: [
                { kind: 'CronJob', name: 'other-cronjob' }
              ]
            },
            status: {
              startTime: '2024-01-01T08:00:00Z',
              succeeded: 1
            }
          }
        ]
      }.to_json
    end

    before do
      kubectl = instance_double(K8::Kubectl)
      allow(K8::Kubectl).to receive(:from_project).with(project).and_return(kubectl)
      allow(kubectl).to receive(:call).with("get jobs -n #{project.name} -o json").and_return(job_response)
    end

    it 'returns job runs for the service' do
      history = cron_job.run_history

      expect(history.length).to eq(2)
      expect(history.map(&:name)).to eq([ 'test-job-1', 'test-job-2' ])
    end

    it 'sorts jobs by start time in descending order' do
      history = cron_job.run_history

      expect(history.first.name).to eq('test-job-1')
      expect(history.last.name).to eq('test-job-2')
    end

    it 'correctly determines job status' do
      history = cron_job.run_history

      expect(history.first.status).to eq(:succeeded)
      expect(history.last.status).to eq(:failed)
    end

    it 'calculates duration correctly' do
      history = cron_job.run_history

      expect(history.first.duration).to eq(300) # 5 minutes
      expect(history.last.duration).to eq(600) # 10 minutes
    end

    it 'returns JobRun structs with correct attributes' do
      job_run = cron_job.run_history.first

      expect(job_run).to be_a(K8::Stateless::CronJob::JobRun)
      expect(job_run.name).to eq('test-job-1')
      expect(job_run.status).to eq(:succeeded)
      expect(job_run.started_at).to eq(Time.parse('2024-01-01T10:00:00Z'))
      expect(job_run.finished_at).to eq(Time.parse('2024-01-01T10:05:00Z'))
      expect(job_run.duration).to eq(300)
    end

    context 'when job is running' do
      let(:job_response) do
        {
          items: [
            {
              metadata: {
                name: 'running-job',
                ownerReferences: [
                  { kind: 'CronJob', name: service.name }
                ]
              },
              status: {
                startTime: '2024-01-01T10:00:00Z',
                active: 1
              }
            }
          ]
        }.to_json
      end

      it 'identifies running jobs' do
        history = cron_job.run_history

        expect(history.first.status).to eq(:running)
        expect(history.first.finished_at).to be_nil
      end
    end

    context 'when no jobs exist' do
      let(:job_response) { { items: [] }.to_json }

      it 'returns empty array' do
        expect(cron_job.run_history).to eq([])
      end
    end
  end
end
