require "rails_helper"

RSpec.describe ShellSessionsController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:user) { account.owner }
  let(:cluster) { create(:cluster, account: account) }
  let(:file) { fixture_file_upload("spec/fixtures/files/test_upload.txt", "text/plain") }

  before { sign_in user }

  describe "DELETE #destroy" do
    it "destroys the user's connected session" do
      session = create(:shell_token, user: user, cluster: cluster, connected_at: Time.current)

      expect {
        delete shell_session_path(session)
      }.to change(ShellToken, :count).by(-1)
    end

    it "cannot destroy another user's session or a pending session" do
      other_user = create(:user)
      other_session = create(:shell_token, user: other_user, cluster: cluster, connected_at: Time.current)
      pending_session = create(:shell_token, user: user, cluster: cluster, connected_at: nil)

      expect { delete shell_session_path(other_session) }.not_to change(ShellToken, :count)
      expect { delete shell_session_path(pending_session) }.not_to change(ShellToken, :count)
    end
  end

  describe "POST #upload" do
    let!(:session) { create(:shell_token, user: user, cluster: cluster, connected_at: Time.current) }

    it "rejects upload when no file is provided" do
      post upload_shell_session_path(session)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to eq("No file provided")
    end

    it "cannot upload to another user's session" do
      other_user = create(:user)
      other_session = create(:shell_token, user: other_user, cluster: cluster, connected_at: Time.current)

      post upload_shell_session_path(other_session), params: { file: file }

      expect(response).not_to have_http_status(:ok)
    end
  end
end
