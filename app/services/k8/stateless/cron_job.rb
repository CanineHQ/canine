class K8::Stateless::CronJob < K8::Base
  JobRun = Struct.new(:name, :status, :started_at, :finished_at, :duration, keyword_init: true)

  attr_accessor :service, :project
  delegate :name, to: :service
  def initialize(service)
    @service = service
    @project = service.project
  end

  def run_history
    jobs = fetch_jobs_for_cronjob
    jobs.map { |job| build_job_run(job) }
       .sort_by { |job| job.started_at || Time.now }
       .reverse
  end

  private

  def fetch_jobs_for_cronjob
    kubectl = K8::Kubectl.from_project(project)
    result = kubectl.call("get jobs -n #{project.name} -o json")
    all_jobs = JSON.parse(result, object_class: OpenStruct).items

    # Filter jobs owned by this CronJob
    all_jobs.select do |job|
      job.metadata.ownerReferences&.any? do |ref|
        ref.kind == 'CronJob' && ref.name == name
      end
    end
  end

  def build_job_run(job)
    JobRun.new(
      name: job.metadata.name,
      status: determine_job_status(job),
      started_at: parse_time(job.status.startTime),
      finished_at: parse_time(job.status.completionTime),
      duration: calculate_duration(job)
    )
  end

  def determine_job_status(job)
    if job.status.active&.positive?
      :running
    elsif job.status.succeeded&.positive?
      :succeeded
    elsif job.status.failed&.positive?
      :failed
    else
      :pending
    end
  end

  def parse_time(time_string)
    return nil if time_string.nil?
    Time.parse(time_string)
  rescue
    nil
  end

  def calculate_duration(job)
    return nil unless job.status.startTime

    end_time = job.status.completionTime ? Time.parse(job.status.completionTime) : Time.now
    start_time = Time.parse(job.status.startTime)

    (end_time - start_time).to_i
  end
end
