class Projects::DoctorJob < ApplicationJob
  queue_as :default

  good_job_control_concurrency_with(
    perform_limit: 1,
    enqueue_limit: 1,
    key: -> { "doctor_#{arguments.first.id}" }
  )

  discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

  def perform(project, user)
    Projects::Doctor.execute(project: project, user: user)
  end
end
