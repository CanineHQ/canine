class Scheduled::CancelHangingDeploysJob < ApplicationJob
  queue_as :default

  def perform
    Deployment.where(status: :in_progress).where(created_at: ..1.hour.ago).each do |deployment|
      deployment.failed!
    end
  end
end
