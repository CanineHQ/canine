require 'rails_helper'

RSpec.describe AddOnsController, type: :controller do
  let(:account) { create(:account) }
  let(:add_on) { create(:add_on, account: account) }
  
  before do
    sign_in(account)
  end

  describe "GET #index" do
    it "returns a success response" do
      get :index
      expect(response).to be_successful
    end
  end

  describe "GET #show" do
    it "returns a success response" do
      get :show, params: { id: add_on.id }
      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    let(:valid_params) { { add_on: { name: "test", chart_type: "redis", chart_url: "https://example.com" } } }

    it "creates a new add_on" do
      expect {
        post :create, params: valid_params
      }.to change(AddOn, :count).by(1)
    end

    it "enqueues install job" do
      expect {
        post :create, params: valid_params
      }.to have_enqueued_job(AddOns::InstallJob)
    end
  end

  describe "PUT #update" do
    let(:new_attributes) { { name: "updated name" } }

    it "updates the add_on" do
      put :update, params: { id: add_on.id, add_on: new_attributes }
      add_on.reload
      expect(add_on.name).to eq("updated name")
    end

    it "enqueues install job" do
      expect {
        put :update, params: { id: add_on.id, add_on: new_attributes }
      }.to have_enqueued_job(AddOns::InstallJob)
    end
  end

  describe "DELETE #destroy" do
    it "marks add_on as uninstalling" do
      delete :destroy, params: { id: add_on.id }
      add_on.reload
      expect(add_on.status).to eq("uninstalling")
    end

    it "enqueues uninstall job" do
      expect {
        delete :destroy, params: { id: add_on.id }
      }.to have_enqueued_job(AddOns::UninstallJob)
    end
  end
end 