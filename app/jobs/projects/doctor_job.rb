class Projects::DoctorJob < ApplicationJob
  queue_as :default

  def perform(project, user)
    Projects::Doctor.execute(project: project, user: user)
  end
end
