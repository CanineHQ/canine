require "rails_helper"

RSpec.describe Cli::RunAndLog do
  it "logs and raises a command failure when the program isn't installed" do
    cluster = create(:cluster)

    expect { described_class.new(cluster).call(%w[definitely-not-a-real-program --version]) }
      .to raise_error(Cli::CommandFailedError, /`definitely-not-a-real-program` isn't installed/)
    expect(cluster.log_outputs.last.output).to include("`definitely-not-a-real-program` isn't installed or isn't on the PATH")
  end
end
