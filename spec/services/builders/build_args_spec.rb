require "rails_helper"

RSpec.describe "Build args" do
  let(:project) { create(:project) }
  let(:build) { create(:build, project: project) }

  before do
    create(:environment_variable, project: project, name: "PUBLIC_URL", value: "https://example.com")
    create(:environment_variable, :secret, project: project, name: "API_KEY", value: "supersecret")
  end

  it "passes config variables but never secrets to Dockerfile builds" do
    commands = [
      Builders::Frontends::DockerfileBuilder.new(build).construct_buildx_command("/tmp/repo"),
      Builders::BuildCloud.new(build, double(build_cloud: double(name: "builder")))
        .construct_buildx_command(project, "/tmp/repo")
    ]

    commands.each do |command|
      expect(command).to include("--build-arg", "PUBLIC_URL=https://example.com")
      expect(command.join(" ")).not_to include("API_KEY", "supersecret")
    end
  end
end
