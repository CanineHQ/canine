require 'rails_helper'

RSpec.describe InboundWebhooks::GitlabJob, type: :job do
  let(:webhook_body) { JSON.parse(File.read("spec/resources/integrations/gitlab/push_webhook.json")) }
  let(:inbound_webhook) { create(:inbound_webhook, body: webhook_body.to_json) }
  let(:current_user) { create(:user) }

  describe '#perform' do
    context 'when webhook is a push event' do
      it 'processes the webhook and creates a build for matching project' do
        project = create(:project,
          repository_url: "czhu12/echo",
          branch: "master",
          autodeploy: true
        )

        expect { described_class.perform_now(inbound_webhook, current_user: current_user) }
          .to change { project.builds.count }.by(1)

        expect(project.builds.last.commit_sha).to eq("37a8fd5aca47a123e2e9932089707747a8a19c0a")
        expect(project.builds.last.commit_message).to eq("added working version")
      end

      it 'does not create build for non-matching project' do
        create(:project,
          repository_url: "different/project",
          branch: "main",
          autodeploy: true
        )

        expect { described_class.perform_now(inbound_webhook, current_user: current_user) }
          .not_to change { Build.count }
      end
    end

    context 'when webhook is not a push event' do
      let(:webhook_body) do
        { "object_kind" => "merge_request" }
      end

      before do
        allow(inbound_webhook).to receive(:body).and_return(webhook_body.to_json)
      end

      it 'does not process the webhook' do
        expect { described_class.perform_now(inbound_webhook, current_user: current_user) }
          .not_to change { Build.count }
      end
    end
  end
end
