# == Schema Information
#
# Table name: shell_tokens
#
#  id         :bigint           not null, primary key
#  container  :string
#  expires_at :datetime         not null
#  namespace  :string           not null
#  pod_name   :string           not null
#  token      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_shell_tokens_on_cluster_id  (cluster_id)
#  index_shell_tokens_on_token       (token) UNIQUE
#  index_shell_tokens_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (user_id => users.id)
#
require 'rails_helper'

RSpec.describe ShellToken, type: :model do
  describe "callbacks" do
    it "auto-generates a token and sets expiry on create" do
      shell_token = create(:shell_token)
      expect(shell_token.token).to be_present
      expect(shell_token.token.length).to be >= 32
      expect(shell_token.expires_at).to be_within(1.second).of(5.minutes.from_now)
    end

    it "generates unique tokens for each record" do
      token1 = create(:shell_token)
      token2 = create(:shell_token)
      expect(token1.token).not_to eq(token2.token)
    end
  end

  describe "#expired?" do
    it "returns false when expires_at is in the future" do
      shell_token = create(:shell_token)
      expect(shell_token.expired?).to be false
    end

    it "returns true when expires_at is in the past" do
      shell_token = create(:shell_token)
      shell_token.update_column(:expires_at, 1.minute.ago)
      expect(shell_token.expired?).to be true
    end
  end

  describe ".active" do
    it "returns only non-expired tokens" do
      active_token = create(:shell_token)
      expired_token = create(:shell_token)
      expired_token.update_column(:expires_at, 1.minute.ago)

      expect(described_class.active).to include(active_token)
      expect(described_class.active).not_to include(expired_token)
    end
  end

  describe "format validations" do
    it "rejects pod_name and namespace with invalid characters" do
      shell_token = build(:shell_token, pod_name: "pod; rm -rf /", namespace: "ns && echo pwned")
      expect(shell_token).not_to be_valid
      expect(shell_token.errors[:pod_name]).to be_present
      expect(shell_token.errors[:namespace]).to be_present
    end

    it "rejects invalid container names" do
      shell_token = build(:shell_token, container: "rails$(whoami)")
      expect(shell_token).not_to be_valid
      expect(shell_token.errors[:container]).to be_present
    end

    it "accepts valid Kubernetes names" do
      shell_token = build(:shell_token, pod_name: "web-app-6d4f5b8c9-x2j7k", namespace: "production", container: "rails")
      expect(shell_token).to be_valid
    end
  end

  describe ".generate_for" do
    it "creates a shell token with the given attributes" do
      user = create(:user)
      cluster = create(:cluster)

      shell_token = described_class.generate_for(
        user: user,
        cluster: cluster,
        pod_name: "web-pod-123",
        namespace: "production",
        container: "rails"
      )

      expect(shell_token).to be_persisted
      expect(shell_token.user).to eq(user)
      expect(shell_token.cluster).to eq(cluster)
      expect(shell_token.pod_name).to eq("web-pod-123")
      expect(shell_token.namespace).to eq("production")
      expect(shell_token.container).to eq("rails")
    end

    it "works without a container" do
      shell_token = described_class.generate_for(
        user: create(:user),
        cluster: create(:cluster),
        pod_name: "web-pod-123",
        namespace: "production"
      )

      expect(shell_token).to be_persisted
      expect(shell_token.container).to be_nil
    end
  end

  describe ".cleanup_expired!" do
    it "deletes expired tokens and keeps active ones" do
      active_token = create(:shell_token)
      expired_token = create(:shell_token)
      expired_token.update_column(:expires_at, 1.minute.ago)

      expect { described_class.cleanup_expired! }.to change(described_class, :count).by(-1)
      expect(described_class.exists?(active_token.id)).to be true
      expect(described_class.exists?(expired_token.id)).to be false
    end
  end
end
