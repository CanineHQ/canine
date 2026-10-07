require "rails_helper"

RSpec.describe AgentLoop::Spec do
  it "gives the run's times in the person's time zone when the task has one, and warns about UTC when it doesn't" do
    session = AgentSession.new(window_from: Time.utc(2026, 10, 3, 0, 40), window_to: Time.utc(2026, 10, 3, 1, 40))

    zoned = described_class.times(session, described_class.normalize("time_zone" => "America/New_York"))
    expect(zoned).to include("America/New_York", "Fri 2 Oct 2026 8:40 PM EDT to Fri 2 Oct 2026 9:40 PM EDT")

    unzoned = described_class.times(session, described_class.normalize({}))
    expect(unzoned).to include("clock is UTC", "2026-10-03T00:40:00Z")
  end
end
