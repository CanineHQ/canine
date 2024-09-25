class Clusters::Install < ApplicationJob
  include Sidekiq::Worker

  def perform(cluster)
    Clusters::Install.call(cluster)
  end
end