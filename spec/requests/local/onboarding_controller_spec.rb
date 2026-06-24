require 'rails_helper'

RSpec.describe "Local::Onboarding", type: :request do
  before do
    allow(Rails.application.config).to receive(:local_mode).and_return(true)
    Rails.application.reload_routes!
  end

  after do
    allow(Rails.application.config).to receive(:local_mode).and_call_original
    Rails.application.reload_routes!
  end

  describe "redirect_if_onboarded" do
    context "when no users exist" do
      it "allows access to the onboarding page" do
        allow(K8::Connection).to receive(:in_cluster?).and_return(false)
        get local_onboarding_index_path
        expect(response).to have_http_status(:ok)
      end

      it "allows access to the create action" do
        post local_onboarding_index_path, params: { onboarding_method: "invalid" }
        expect(response).to redirect_to(local_onboarding_index_path)
      end
    end

    context "when a user already exists" do
      before { create(:account) }

      it "redirects index to sign-in" do
        get local_onboarding_index_path
        expect(response).to redirect_to(new_user_session_path)
      end

      it "redirects create to sign-in" do
        post local_onboarding_index_path, params: { onboarding_method: "normal" }
        expect(response).to redirect_to(new_user_session_path)
      end

      it "redirects account_select to sign-in" do
        get account_select_local_onboarding_index_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
