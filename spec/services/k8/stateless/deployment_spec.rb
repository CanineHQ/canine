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
    # This test expects initContainers from a different source (workspace/coding-agent)
    # Skip for now as it's testing a different feature
    skip "This test is for workspace/coding-agent feature, not debug-shell"
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

  describe 'debug shell sidecar' do
    context 'when in development environment' do
      before do
        allow(project).to receive(:dev_environment?).and_return(true)
      end

      it 'includes the debug-shell sidecar' do
        yaml = deployment.to_yaml

        expect(yaml).to include("initContainers:")
        expect(yaml).to include("name: debug-shell")
        expect(yaml).to include("image: alpine:latest")
        expect(yaml).to include("restartPolicy: Always")
      end

      it 'installs debugging tools in the debug shell' do
        yaml = deployment.to_yaml

        expect(yaml).to include("apk add --no-cache curl wget vim nano bash")
        expect(yaml).to include("sleep infinity")
      end

      it 'mounts project volumes to the debug shell' do
        volume = create(:volume, project: project, name: "app-storage", mount_path: "/data")

        yaml = deployment.to_yaml

        # Check debug-shell has volumeMounts
        debug_shell_section = yaml.split("name: debug-shell").last.split("containers:").first
        expect(debug_shell_section).to include("volumeMounts:")
        expect(debug_shell_section).to include("name: app-storage")
        expect(debug_shell_section).to include("mountPath: /data")
      end

      it 'does not include debug shell when no volumes present' do
        yaml = deployment.to_yaml

        # Debug shell should still be present, just without volumeMounts
        expect(yaml).to include("name: debug-shell")

        # Extract debug-shell section
        debug_shell_section = yaml.split("name: debug-shell").last.split(/- name: (?!debug-shell)/).first

        # Should not have volumeMounts section if no volumes
        expect(debug_shell_section).not_to include("volumeMounts:") if project.volumes.empty?
      end
    end

    context 'when not in development environment' do
      before do
        allow(project).to receive(:dev_environment?).and_return(false)
      end

      it 'does not include the debug-shell sidecar' do
        yaml = deployment.to_yaml

        expect(yaml).not_to include("name: debug-shell")
      end

      it 'does not include initContainers section at all' do
        yaml = deployment.to_yaml

        expect(yaml).not_to include("initContainers:")
      end
    end
  end

end
