# == Schema Information
#
# Table name: clusters
#
#  id           :bigint           not null, primary key
#  cluster_type :integer          default("k8s")
#  kubeconfig   :jsonb
#  name         :string           not null
#  status       :integer          default("initializing"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  external_id  :string
#
# Indexes
#
#  index_clusters_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
FactoryBot.define do
  factory :cluster do
    account
    sequence(:name) { |n| "test-cluster-#{n}" }
    kubeconfig do
      {
        "apiVersion" => "v1",
        "clusters" => [ { "name" => "test-cluster", "cluster" => { "server" => "https://example.com" } } ],
        "contexts" => [ { "name" => "test-cluster", "context" => { "cluster" => "test-cluster", "user" => "test-user" } } ],
        "current-context" => "test-cluster",
        "users" => [ { "name" => "test-user", "user" => { "token" => "test-token" } } ]
      }.to_json
    end
    status { :initializing }
    cluster_type { :k8s }
  end
end
