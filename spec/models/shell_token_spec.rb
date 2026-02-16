# == Schema Information
#
# Table name: shell_tokens
#
#  id           :bigint           not null, primary key
#  connected_at :datetime
#  container    :string
#  expires_at   :datetime         not null
#  namespace    :string           not null
#  pod_name     :string           not null
#  token        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cluster_id   :bigint           not null
#  user_id      :bigint           not null
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

  describe "#mark_connected!" do
    it "sets connected_at timestamp" do
      shell_token = create(:shell_token)
      expect(shell_token.connected_at).to be_nil

      shell_token.mark_connected!
      expect(shell_token.connected_at).to be_within(1.second).of(Time.current)
    end
  end

  describe ".active_session_count" do
    it "counts only connected sessions for a user" do
      user = create(:user)
      create(:shell_token, user: user)
      connected = create(:shell_token, user: user)
      connected.mark_connected!

      other_user = create(:user)
      other_connected = create(:shell_token, user: other_user)
      other_connected.mark_connected!

      expect(described_class.active_session_count(user)).to eq(1)
    end
  end

  describe ".cleanup_expired!" do
    it "deletes expired pending tokens but keeps connected ones" do
      active_token = create(:shell_token)
      expired_pending = create(:shell_token)
      expired_pending.update_column(:expires_at, 1.minute.ago)
      expired_connected = create(:shell_token)
      expired_connected.mark_connected!
      expired_connected.update_column(:expires_at, 1.minute.ago)

      expect { described_class.cleanup_expired! }.to change(described_class, :count).by(-1)
      expect(described_class.exists?(active_token.id)).to be true
      expect(described_class.exists?(expired_connected.id)).to be true
      expect(described_class.exists?(expired_pending.id)).to be false
    end
  end

  describe ".cleanup_stale_sessions!" do
    it "deletes connected sessions older than the idle timeout" do
      recent = create(:shell_token)
      recent.mark_connected!

      stale = create(:shell_token)
      stale.update!(connected_at: 31.minutes.ago)

      expect { described_class.cleanup_stale_sessions! }.to change(described_class, :count).by(-1)
      expect(described_class.exists?(recent.id)).to be true
      expect(described_class.exists?(stale.id)).to be false
    end
  end
end
