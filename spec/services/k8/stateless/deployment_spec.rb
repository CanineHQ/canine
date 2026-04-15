require 'rails_helper'

RSpec.describe K8::Stateless::Deployment do
  around do |example|
    original_image = ENV["CODING_AGENT_SIDECAR_IMAGE"]
    original_command = ENV["CODING_AGENT_SIDECAR_COMMAND"]
    ENV["CODING_AGENT_SIDECAR_IMAGE"] = "ghcr.io/example/coding-agent:latest"
    ENV["CODING_AGENT_SIDECAR_COMMAND"] = "sleep infinity"
    example.run
  ensure
    ENV["CODING_AGENT_SIDECAR_IMAGE"] = original_image
    ENV["CODING_AGENT_SIDECAR_COMMAND"] = original_command
  end

  let(:project) { create(:project) }
  let(:service) { create(:service, project: project, command: "bin/dev") }
  let(:deployment) { described_class.new(service) }

  before do
    project.build_configuration.update!(development_dockerfile_path: "./Dockerfile.dev")
  end

  it 'renders the development workspace init container and coding sidecar' do
    yaml = deployment.to_yaml

    expect(yaml).to include("initContainers:")
    expect(yaml).to include("name: hydrate-workspace")
    expect(yaml).to include("name: workspace")
    expect(yaml).to include("emptyDir: {}")
    expect(yaml).to include("name: coding-agent")
    expect(yaml).to include("image: ghcr.io/example/coding-agent:latest")
    expect(yaml).to include("workingDir: /app")
  end

  it 'merges custom pod spec extras without replacing the primary container' do
    service.update!(pod_yaml: {
      "serviceAccountName" => "builder",
      "containers" => [
        {
          "name" => "debugger",
          "image" => "busybox:1.36"
        }
      ],
      "volumes" => [
        {
          "name" => "cache",
          "emptyDir" => {}
        }
      ]
    })

    yaml = deployment.to_yaml

    expect(yaml).to include("serviceAccountName: builder")
    expect(yaml).to include("name: #{project.name}")
    expect(yaml).to include("name: debugger")
    expect(yaml).to include("name: cache")
  end
end
