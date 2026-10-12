require "rails_helper"

RSpec.describe AgentLoop::SystemPrompt do
  it "gives the run's times in the person's time zone when the task has one, and warns about UTC when it doesn't" do
    session = AgentComputer::Session.new(window_from: Time.utc(2026, 10, 3, 0, 40), window_to: Time.utc(2026, 10, 3, 1, 40))

    session.task = AgentComputer::Task.new(time_zone: "America/New_York")
    expect(described_class.times(session)).to include("America/New_York", "Fri 2 Oct 2026 8:40 PM EDT to Fri 2 Oct 2026 9:40 PM EDT")

    session.task = AgentComputer::Task.new
    expect(described_class.times(session)).to include("clock is UTC", "2026-10-03T00:40:00Z")
  end
end
