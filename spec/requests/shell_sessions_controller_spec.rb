require "rails_helper"

RSpec.describe ShellSessionsController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:user) { account.owner }
  let(:cluster) { create(:cluster, account: account) }

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
end
