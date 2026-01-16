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

  describe "create cluster" do
    let(:valid_kubeconfig_output) do
      <<~YAML
        apiVersion: v1
        clusters:
        - cluster:
            certificate-authority-data: dGVzdC1jZXJ0LWRhdGE=
            server: https://127.0.0.1:6443
          name: default
        contexts:
        - context:
            cluster: default
            user: default
          name: default
        current-context: default
        kind: Config
        preferences: {}
        users:
        - name: default
          user:
            token: test-token-12345
      YAML
    end

    before do
      allow(Clusters::InstallJob).to receive(:perform_later)
    end

    it "creates a new external k3s cluster" do
      visit new_cluster_path
      fill_in "cluster_name", with: "my-k3s-cluster"
      find('[data-card-name="k3s"]').click

      fill_in "cluster_ip_address", with: "192.168.1.100"

      # Show and fill the kubeconfig field directly via JS (bypassing step validation)
      page.execute_script("document.querySelectorAll('[data-k3s-instructions-target=\"step\"]').forEach(s => s.classList.remove('hidden'))")
      page.execute_script("document.querySelector('[data-k3s-instructions-target=\"next\"]').type = 'submit'")
      page.execute_script("document.querySelector('[data-k3s-instructions-target=\"next\"]').innerHTML = 'Submit'")

      fill_in "cluster_k3s_kubeconfig_output", with: valid_kubeconfig_output
      click_button "Submit"

      expect(page).to have_content("Cluster was successfully created")
      expect(Cluster.last).to have_attributes(name: "my-k3s-cluster", cluster_type: "k3s")
      expect(Clusters::InstallJob).to have_received(:perform_later)
    end

    it "creates a new local k3s cluster" do
      visit new_cluster_path
      fill_in "cluster_name", with: "my-local-cluster"
      find('[data-card-name="local_k3s"]').click

      fill_in "cluster_local_k3s_kubeconfig_output", with: valid_kubeconfig_output
      click_button "Create Cluster"

      expect(page).to have_content("Cluster was successfully created")
      expect(Cluster.last).to have_attributes(name: "my-local-cluster", cluster_type: "local_k3s")
      expect(Clusters::InstallJob).to have_received(:perform_later)
    end

    it "creates a new managed k8s cluster" do
      kubeconfig_file = Tempfile.new([ 'kubeconfig', '.yaml' ])
      kubeconfig_file.write(valid_kubeconfig_output)
      kubeconfig_file.rewind

      visit new_cluster_path
      fill_in "cluster_name", with: "my-k8s-cluster"
      find('[data-card-name="k8s"]').click

      attach_file "cluster_kubeconfig_file", kubeconfig_file.path
      click_button "Submit"

      expect(page).to have_content("Cluster was successfully created")
      expect(Cluster.last).to have_attributes(name: "my-k8s-cluster", cluster_type: "k8s")
      expect(Clusters::InstallJob).to have_received(:perform_later)
    ensure
      kubeconfig_file.close
      kubeconfig_file.unlink
    end
  end
end
