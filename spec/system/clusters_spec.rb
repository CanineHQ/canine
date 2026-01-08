require 'rails_helper'

RSpec.describe "Clusters", type: :system do
  attr_reader :user, :account

  before do
    result = sign_in_user
    @user = result[:user]
    @account = result[:account]

    k8_client = instance_double(K8::Client)
    allow(K8::Client).to receive(:new).and_return(k8_client)
    allow(k8_client).to receive(:version).and_return({ 'serverVersion' => { 'gitVersion' => 'v1.28.0' } })
    allow(k8_client).to receive(:can_connect?).and_return(true)
    allow(k8_client).to receive(:server).and_return("https://example.com")
  end

  describe "index" do
    it "lists existing clusters" do
      cluster = create(:cluster, account: account, name: "my-cluster")

      visit clusters_path

      expect(page).to have_content("my-cluster")
    end
  end

  describe "show" do
    it "displays cluster details" do
      cluster = create(:cluster, account: account, name: "production-cluster")

      visit cluster_path(cluster)

      expect(page).to have_content("production-cluster")
      expect(page).to have_content("Configuration")
      expect(page).to have_link("Download Kubeconfig File")
    end
  end

  describe "edit" do
    it "allows updating cluster name" do
      cluster = create(:cluster, account: account, name: "old-name")

      visit edit_cluster_path(cluster)

      fill_in "cluster_name", with: "new-name"
      click_button "Save"

      expect(page).to have_content("Cluster was successfully updated")
      expect(cluster.reload.name).to eq("new-name")
    end
  end

  describe "delete" do
    it "removes the cluster" do
      cluster = create(:cluster, account: account, name: "to-delete")

      visit edit_cluster_path(cluster)

      accept_confirm do
        click_button "Delete Cluster"
      end

      expect(page).to have_content("Cluster is being deleted")
      expect(page).to have_current_path(clusters_path)
    end
  end
end
