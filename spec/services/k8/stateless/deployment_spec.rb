require 'rails_helper'

RSpec.describe K8::Stateless::Deployment do
  let(:project) { create(:project) }
  let(:service) { create(:service, project: project, command: "bin/dev") }
  let(:deployment) { described_class.new(service) }

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

  describe 'development environment git clone' do
    let(:parent_project) { create(:project) }
    let(:development_environment_configuration) do
      create(:development_environment_configuration,
        project: parent_project,
        enabled: true,
        workspace_mount_path: "/workspace")
    end

    context 'when in development environment' do
      before do
        development_environment_configuration
        create(:development_environment, child_project: project, parent_project: parent_project)
        project.reload
      end

      it 'includes the git-clone init container' do
        yaml = deployment.to_yaml

        expect(yaml).to include("initContainers:")
        expect(yaml).to include("name: git-clone")
        expect(yaml).to include("image: alpine/git:latest")
        expect(yaml).not_to include("name: rover")
      end

      it 'does not include a rover sidecar' do
        yaml = deployment.to_yaml

        expect(yaml).not_to include("ghcr.io/caninehq/rover")
        expect(yaml).not_to include("restartPolicy: Always")
      end

      it 'mounts project volumes to the git-clone init container' do
        create(:volume, project: project, name: "app-storage", mount_path: "/data")

        yaml = deployment.to_yaml
        clone_section = yaml.split("name: git-clone").last.split("containers:").first

        expect(clone_section).to include("volumeMounts:")
        expect(clone_section).to include("name: app-storage")
        expect(clone_section).to include("mountPath: /data")
      end
    end

    context 'when not in development environment' do
      it 'does not include init containers' do
        yaml = deployment.to_yaml

        expect(yaml).not_to include("name: git-clone")
        expect(yaml).not_to include("initContainers:")
      end
    end
  end
end
