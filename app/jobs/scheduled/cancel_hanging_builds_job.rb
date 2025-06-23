class Scheduled::CancelHangingBuildsJob < ApplicationJob
  queue_as :default

  def perform
    Build.where(status: :in_progress).where(created_at: ..1.hour.ago).each do |build|
      build.failed!
    end
  end
end
